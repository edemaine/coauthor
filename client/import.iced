parseXML = (zipdata) ->
  xml = zipdata.asText()
  xml = xml.replace /\x0C/g, 'fi'  ## must be from some LaTeX copy/paste...
  xml = $($.parseXML xml)

bodymap = (body) ->
  ## Turn $$ into $ to convert to new MathJax format.
  body.replace /\$\$/g, '$'

ext2type =
  '.jpg': 'image/jpeg'
  '.jpeg': 'image/jpeg'
  '.png': 'image/png'
  '.pdf': 'application/pdf'
  '.svg': 'image/svg+xml'

upfile_url = ///http://6...\.csail\.mit\.edu/[^/\s"=]*/upfiles/([^/\s"=]*)///g

importOSQA = (group, zip) ->
  zip = new JSZip zip

  files = {}
  for filename, content of zip.files
    if filename[...8] == 'upfiles/'
      filename = filename[8..]
      continue unless filename.length > 0
      continue if filename == 'README'  ## extra file
      dot = filename.lastIndexOf '.'
      if dot >= 0
        ext = filename[dot..].toLowerCase()
      else
        ext = ''
      if ext not of ext2type
        console.error "Unrecognized extension '#{ext}' in imported file '#{filename}'"
        return  ## don't do a partial import
      ## JSZip's ZipObjects don't seem to behave enough like a File.
      #content.type = ext2type[ext]
      #files[filename] = content
      do (filename, content, type = ext2type[ext]) ->
        files[filename] = ->
          new File [content.asArrayBuffer()], filename,
            type: type
            lastModified: content.date

  users = parseXML zip.files['users.xml']
  usermap = {}
  for user in users.find 'user'
    user = $(user)
    id = user.children('id').text()
    username = user.children('username').text()
    usermap[id] = username
  #console.log usermap
  mapauthor = (author) ->
    if usermap[author]?
      usermap[author]
    else
      console.error 'no mapping for user', author
      author

  actions = parseXML zip.files['actions.xml']
  deleted = {}
  for action in actions.find 'action'
    action = $(action)
    type = action.children('type').text()
    if type == 'delete'
      node = action.children('node').text()
      if action.children('canceled').attr('state') == 'false'
        ## Canceled deletions don't seem to have a cancelation date,
        ## so we can't create delete and undelete events in the history.
        ## Instead, just ignored canceled deletions.
        deleted[node] =
          deleted: true
          updated: new Date action.children('date').text()
          updators: [mapauthor action.children('user').text()]

  nodes = parseXML zip.files['nodes.xml']
  idmap = {}
  count = 0
  for node in nodes.find('node')
    node = $(node)
    id = node.children('id').text()
    parent = node.children('parent').text()
    if parent
      if idmap[parent]?
        parent = idmap[parent]
      else
        console.error id, 'before parent', parent
        break
    else
      parent = null
    revisions = for revision in node.children('revisions').children('revision')
      revision = $(revision)
      updated: new Date revision.children('date').text()
      updators: [mapauthor revision.children('author').text()]
      title: revision.children('title').text()
      body: bodymap revision.children('body').text()
      tags: $(tag).text() for tag in revision.children('tags').children('tag')
      ## ignoring number (always sequential), summary (blank change log)
    message =
      #type: node.children('type').text()  ## no real use; implied by tree
      created: new Date node.children('date').text()
      creator: mapauthor node.children('author').text()
      title: node.children('title').text()
      body: bodymap node.children('body').text()
      tags: $(tag).text() for tag in node.children('tags').children('tag')
      ## ignoring lastactivity (summary field), absparent (always same as
      ## parent), score (useless), marked (?), wiki (useless),
      ## extraRef, extraData, extraCount (always empty)
      format: 'markdown'

    usedFiles = {}
    for revision in revisions
      matches = revision.body.match upfile_url
      continue unless matches?
      for match in matches
        filename = match[match.lastIndexOf('/')+1..]
        if filename not of files
          console.warn "Missing file #{filename} in #{revision.body}!"
        else if filename not of usedFiles  ## take first occurrence
          usedFiles[filename] = revision

    attachFiles = []
    await
      for filename, revision of usedFiles
        if typeof files[filename] == 'function'
          file = files[filename]()
          ## Assume file created by same person and roughly same time
          ## as the first post that contains them.  OSQA doesn't seem to
          ## keep any record of files, so that's the best we can do.
          file.creator = revision.updators[0]
          file.created = revision.updated
          file.group = group
          do (d = defer files[filename]) ->
            file.callback = (file2) ->
              attachFiles.push file2
              d file2.uniqueIdentifier
          Files.resumable.addFile file

    for revision in revisions
      revision.body = revision.body.replace upfile_url, (match, p1) ->
        if p1 of files
          urlToFile files[p1]
        else
          match

    revisions[0].format = message.format
    ## message.body is actually the rendered HTML.  To get markdown format
    ## (as well as file substitutions done above), use last revision:
    message.body = revisions[revisions.length-1].body
    if id of deleted
      message.deleted = true
      revisions.push deleted[id]
    else
      message.deleted = false
    message.published = revisions[0].published = message.created
    await Meteor.call 'messageImport', group, parent, message, revisions, defer error, idmap[id]
    throw error if error
    count += 1
    #return if count == 5

    await
      for file2 in attachFiles
        ## Last modified date of the physical file (as preserved in ZIP)
        ## is generally earlier than the time of the post using the file,
        ## so is more accurate.  Just in case, take the min of the two.
        if file2.file.created.getTime() < file2.file.lastModifiedDate.getTime()
          #console.log file2.file.created, file2.file.lastModifiedDate
          creation = file2.file.created
        else
          creation = file2.file.lastModifiedDate
        filerev =
          format: 'file'
          title: file2.fileName
          body: file2.uniqueIdentifier
          published: creation
        filemsg = _.clone filerev
        filemsg.creator = file2.file.creator
        filemsg.created = creation
        filerev.updators = [file2.file.creator]
        filerev.updated = creation
        Meteor.call 'messageImport', group, idmap[id], filemsg, [filerev],
          defer()  ## ignoring error

importOSQA.readAs = 'ArrayBuffer'

lastName = (x) ->
  x = x.replace /[{}]/g, ''
  if ' ' in x
    x[x.lastIndexOf(' ')+1..]
  else
    x

basename = (path) ->
  if '/' in path
    path[path.lastIndexOf('/')+1..]
  else
    path

path2ext = (path) ->
  if '.' in path
    path[path.lastIndexOf('.')..]
  else
    ''

importLaTeX = (group, zip) ->
  me = Meteor.user().username
  zip = new JSZip zip

  ## Extract bib entries.
  bibs = {}
  for filename, content of zip.files
    if filename[-4..] == '.bib'
      bib = content.asText()
      r = /@[\w\s]*{([^,]*),[^@]*?\burl\s*=\s*("[^"]*"|{[^{}]*})/ig
      while (match = r.exec bib)?
        author = /\bauthor\s*=\s*("(?:{[^{}]*}|[^"])*"|{(?:[^{}]|{[^{}]*})*})/i.exec match[0]
        console.log match[0] unless author
        author = author[1][1...-1].split /\s*\band\b\s*/i
        author = for auth in author
          if ',' in auth
            auth[auth.indexOf(',')+1..].trim() + ' ' + auth[...auth.indexOf ','].trim()
          else
            auth
        year = /\byear\s*=\s*("(?:{[^{}]*}|[^"])*"|{(?:[^{}]|{[^{}]*})*}|\d+)/i.exec match[0]
        year = year[1].replace /["{}]/g, ''
        if author.length <= 1
          abbrev = /([^{}]|{[^{}]*}){1,3}/.exec(lastName author[0])[0].replace /[{}]/g, ''
        else
          abbrev = (lastName(auth)[0] for auth in author).join ''
        abbrev += year[-2..]
        console.log match[1], '=', abbrev, '=', author.join(' & '), year, '=', match[2][1...-1]
        bibs[match[1]] =
          author: author
          year: year
          abbrev: abbrev
          url: match[2][1...-1]

  ## Extract figures.
  figures = {}
  for filename, content of zip.files
    if filename[-4..] == '.tex'
      tex = content.asText()
      tex = tex.replace /%.*$\n?/mg, ''
      .replace /\\begin\s*{(wrap)?figure}([^\0]*?)\\end\s*{(wrap)?figure}\s*/g,
        (match, p1, p2, p3) ->
          graphics = []
          gr = /\\includegraphics\s*(\[[^\[\]]*\]\s*)?{((?:[^{}]|{[^{}]*})*)}/g
          while (match = gr.exec p2)?
            filename = match[2]
            for extension in ['', '.svg', '.png', '.jpg', '.pdf']
              if filename + extension of zip.files
                filename += extension
                break
            if filename not of zip.files
              console.warn "Missing file for \\includegraphics{#{graphics}}"
            graphics.push filename
          caption = /\\caption\s*{((?:[^{}]|{[^{}]*})*)}/.exec p2
          caption = caption[1]
          labels = []
          lr = /\\label\s*{((?:[^{}]|{[^{}]*})*)}/g
          while (match = lr.exec p2)?
            labels.push match[1]
          console.log "Figure #{labels.join ' / '} = #{graphics.join ' & '} = #{caption}"
          figure =
            graphics: graphics
            caption: caption
            labels: labels
          for label in labels
            figures[label] = figure

  ## Extract sections.
  for filename, content of zip.files
    if filename[-4..] == '.tex'
      tex = content.asText()
      ## Remove comments (to ignore \sections inside comments).
      tex = tex
      .replace /%.*$\n?/mg, ''
      .replace /\\begin\s*{(wrap)?figure}[^\0]*?\\end\s*{(wrap)?figure}\s*/g, ''
      .replace /\\cite\s*(?:\[([^\[\]]*)\]\s*)?{([^{}]*)}/g, (match, p1, p2) ->
        '[' + (
          for cite in p2.split ','
            cite = cite.trim()
            bib = bibs[cite]
            if bib?
              "\\href{#{bib.url}}{#{bib.abbrev}}"
            else
              console.warn "Missing bib url for '#{cite}'" unless bib?
              cite
        ).join(', ') + (if p1? then ", #{p1}" else '') + ']'
      depths = []
      start = null
      labels = {}
      messages = []
      figurecount = 0
      r = /\\(sub)*section\s*{((?:[^{}]|{[^{}]*})*)}|\\bibliography/g
      while (match = r.exec tex)?
        if start?
          now = new Date
          body = tex[start...match.index]
          body = body.replace /\\label{([^{}]*)}/, (match, p1) ->
            labels[p1] = title[...title.indexOf ' ']
            ''
          console.log "Importing '#{title}'"
          messages.push
            title: title
            body: body
            created: now
            creator: me
            published: now
            format: 'latex'

        break if match[0] == '\\bibliography'
        depth = Math.floor (match[1] ? '').length / 3
        while depth < depths.length-1
          depths.pop()
        while depth > depths.length-1
          depths.push 0
        depths[depth] += 1

        title = "#{depths.join('.')} #{match[2]}"
        start = match.index + match[0].length

      for message in messages
        attach = []
        message.body = message.body
        .replace /\\ref\s*{([^{}]*)}/, (match, p1) ->
          if p1 of labels
            labels[p1]
          else if p1 of figures
            attach.push figures[p1]
            "``#{figures[p1].labels[figures[p1].labels.length-1]}''"
          else
            console.warn "Unresolved #{match}"
            match
        revision = _.clone message
        revision.updated = revision.created
        delete revision.created
        revision.updators = [revision.creator]
        delete revision.creator
        await Meteor.call 'messageImport', group, null, message, [revision], defer error, message._id

        attach = _.unique attach  ## upload \ref'd figures only once each
        for figure in attach
          figure.message =
            title: "Figure ``#{figure.labels[figure.labels.length-1]}''"
            body: figure.caption
            published: now
            format: 'latex'
          frevision = _.clone figure.message
          figure.message.creator = me
          figure.message.created = now
          frevision.updators = [me]
          frevision.updated = now
          await Meteor.call 'messageImport', group, message._id, figure.message, [frevision], defer error, figure.message._id

        await
          for figure in attach
            figuremsg =
              title: "Figure #{figure.labels[figure.labels.length-1]}"
              body: body

            figure.files = []
            for filename in figure.graphics
              base = basename filename
              file = new File [zip.files[filename].asArrayBuffer()],
                       base,
                       type: ext2type[path2ext base]
                       lastModified: now
              file.creator = me
              file.created = now
              file.group = group
              figure.files.push file
              do (d = defer file.file2id) ->
                file.callback = (file2) ->
                  d file2.uniqueIdentifier
              Files.resumable.addFile file
        await
          for figure in attach
            for file in figure.files
              filerev =
                format: 'file'
                title: file.name
                body: file.file2id
                published: now
              filemsg = _.clone filerev
              filemsg.creator = me
              filemsg.created = now
              filerev.updators = [me]
              filerev.updated = now
              Meteor.call 'messageImport', group, figure.message._id, filemsg, [filerev],
                defer()  ## ignoring error

#importLaTeX.readAs = 'Text'
importLaTeX.readAs = 'ArrayBuffer'

importers =
  'osqa': importOSQA
  'latex': importLaTeX

@importFiles = (format, group, files) ->
  importer = importers[format]
  unless importer?
    console.warn "Unrecognized import format '#{format}'"
    return
  for file in files
    reader = new FileReader
    reader.onload = (e) ->
      importer group, e.target.result
    reader["readAs#{importer.readAs}"] file
