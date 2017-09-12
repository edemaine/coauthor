parseXML = (xml) ->
  xml = xml.replace /\x0C/g, 'fi'  ## must be from some LaTeX copy/paste...
  xml = xml.replace /â€™/g, '’'    ## CP-1253 encoding
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

loadZip = (zipData, callback) ->
  await `importJSZip()`.then defer JSZip
  #await `import('jszip')`.then defer JSZip
  JSZip = JSZip.default
  zip = new JSZip
  console.log 'Loading ZIP file...'
  zip.loadAsync(zipData).then callback

importOSQA = (group, zip) ->
  await loadZip zip, defer zip

  files = {}
  for content in zip.file /^upfiles\//
    filename = content.name
    basename = filename[8..]
    continue unless basename.length > 0
    continue if basename == 'README'  ## extra file
    dot = basename.lastIndexOf '.'
    if dot >= 0
      ext = basename[dot..].toLowerCase()
    else
      ext = ''
    if ext not of ext2type
      console.error "Unrecognized extension '#{ext}' in imported file '#{filename}'"
      return  ## don't do a partial import
    ## JSZip's ZipObjects don't seem to behave enough like a File.
    #content.type = ext2type[ext]
    #files[filename] = content
    #do (basename, filename, content, type = ext2type[ext]) ->
    await zip.file(filename).async('arraybuffer').then defer buffer
    files[basename] = new File [buffer], basename,
      type: type
      lastModified: content.date

  await zip.file('users.xml').async('string').then defer users
  users = parseXML users
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

  await zip.file('actions.xml').async('string').then defer actions
  actions = parseXML actions
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

  ## OSQA uses <tags><tag>tag1</tag><tag>tag2</tag></tags> format for messages,
  ## but <tags>tag1, tag2</tags> for revisions.  Support both in both places.
  importTags = (tagsNode) ->
    tags =
      for tag in tagsNode.children 'tag'
        $(tag).text()
    unless tags.length
      if tagsNode.text()  ## avoid blank string which splits into ['']
        tags = tagsNode.text().split /\s*,\s*/
    listToTags tags

  await zip.file('nodes.xml').async('string').then defer nodes
  nodes = parseXML nodes
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
      tags: importTags revision.children('tags')
      ## ignoring number (always sequential), summary (blank change log)
    message =
      #type: node.children('type').text()  ## no real use; implied by tree
      created: new Date node.children('date').text()
      creator: mapauthor node.children('author').text()
      title: node.children('title').text()
      body: bodymap node.children('body').text()
      tags: importTags node.children('tags')
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
        #if typeof files[filename] == 'function'
        #  await files[filename] defer file
        file = files[filename]
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
      revision.body ?= ''
      revision.body = revision.body.replace upfile_url, (match, p1) ->
        if p1 of files
          urlToInternalFile files[p1]
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
          file: file2.uniqueIdentifier
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
  await loadZip zip, defer zip

  ## Extract bib entries.
  bibs = {}
  for content in zip.file /\.bib$/
    await content.async('string').then defer bib
    r = /@[\w\s]*{([^,]*),[^@]*?\burl\s*=\s*("[^"]*"|{[^{}]*})/ig
    while (match = r.exec bib)?
      author = /\bauthor\s*=\s*("(?:{[^{}]*}|[^"])*"|{(?:[^{}]|{(?:[^{}]|{[^{}]*})*})*})/i.exec match[0]
      console.log match[0] unless author
      author = author[1][1...-1].split /\s*\band\b\s*/i
      author = for auth in author
        if ',' in auth
          auth[auth.indexOf(',')+1..].trim() + ' ' + auth[...auth.indexOf ','].trim()
        else
          auth
      title = /\btitle\s*=\s*("(?:{[^{}]*}|[^"])*"|{(?:[^{}]|{(?:[^{}]|{[^{}]*})*})*})/i.exec match[0]
      console.log match[0] unless title
      title = title[1][1...-1].replace /[{}]/g, ''
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
        title: title
        year: year
        abbrev: abbrev
        url: match[2][1...-1]

  cleanBibTeX = (bib) ->
    ## Convert newlines into spaces for single-line tooltip.
    bib.replace /\s*\n\s*/g, ' '
    ## Remove {}s that aren't used for argument to a command (common in BibTeX).
    .replace /(\\.|\\[a-zA-Z]+\s*)?[{}]/g, (match, p1, p2) ->
      if p1
        match
      else
        ''
  processCites = (tex) ->
    return tex unless tex
    tex.replace /\\cite\s*(?:\[([^\[\]]*)\]\s*)?{([^{}]*)}/g, (match, p1, p2) ->
      '[' + (
        for cite in p2.split ','
          cite = cite.trim()
          bib = bibs[cite]
          if bib?
            "\\pdftooltip{\\href{#{bib.url}}{#{bib.abbrev}}}{``#{cleanBibTeX bib.title}'' by #{cleanBibTeX bib.author.join '; '}}"
          else
            console.warn "Missing bib url for '#{cite}'" unless bib?
            cite
      ).join(', ') + (if p1? then ", #{p1}" else '') + ']'
  findLabels = (text) ->
    [
      labels = []
      text.replace /\\label\s*{((?:[^{}]|{[^{}]*})*)}/g,
        (match, label) ->
          labels.push label
          ''
    ]
  findIncludeGraphics = (text, subcaption = null, labels = []) ->
    graphics = []
    text.replace /\\includegraphics\s*(\[[^\[\]]*\]\s*)?{((?:[^{}]|{[^{}]*})*)}/g,
      (match, optional, filename) ->
        if optional.match /page\s*=/
          console.warn 'Import does not support \\includegraphics[page=...]'
        graphics.push
          filename: filename
          subcaption: subcaption
          labels: labels
        ''
    graphics
  findGraphicFile = (graphic) ->
    for extension in ['', '.svg', '.png', '.jpg', '.pdf']
      if zip.file graphic.filename + extension
        graphic.filename += extension
        if graphic.filename[graphic.filename.length-4..] == '.pdf'
          console.warn "Using pdf graphic #{graphic.filename}"
        break
    if not zip.file graphic.filename
      console.warn "Missing file for \\includegraphics{#{graphic.filename}}"

  ## Extract figures.
  figures = {}
  inlineGraphics = {}
  for content in zip.file /\.tex$/
    await content.async('string').then defer tex
    tex = tex.replace /%.*$\n?/mg, ''
    .replace /\\begin\s*{(wrap)?figure}([^]*?)\\end\s*{(wrap)?figure}\s*/g,
      (match, beginFigure, body, endFigure) ->
        ## Collect all \includegraphics, possibly with subcaptions
        graphics = []
        body = body.replace /\\subcaptionbox\s*{((?:[^{}]|{[^{}]*})*)}\s*{((?:[^{}]|{[^{}]*})*)}/g,
          (match2, subcaption, subbody) ->
            [labels, subcaption] = findLabels subcaption
            graphics.push (findIncludeGraphics subbody, subcaption, labels)...
            ''
        body = body.replace /\\begin\s*{subfigure}([^]*?)\\end\s*{subfigure}/g,
          (match2, subbody) ->
            [labels, subbody] = findLabels subbody
            subcaption = /\\caption\s*{((?:[^{}]|{[^{}]*})*)}/.exec(subbody)?[1]
            graphics.push (findIncludeGraphics subbody, subcaption, labels)...
            ''
        ## subcaption = false for root images
        graphics.push (findIncludeGraphics body, false)...
        ## Search for correct extensions
        for graphic in graphics
          findGraphicFile graphic
        for graphic in graphics
          ## Remove \\ use within subcaption, which is generally just for
          ## layout and not relevant for web layout.
          if graphic.subcaption
            graphic.subcaption = graphic.subcaption.replace /\s*\\\\\s*/, ' '
            graphic.subcaption = processCites graphic.subcaption
        [labels, body] = findLabels body
        caption = /\\caption\s*{((?:[^{}]|{[^{}]*})*)}/.exec(body)[1]
        caption = processCites caption
        console.log "Figure #{labels.join ' / '} = #{(graphic.filename + (if graphic.subcaption then "[#{graphic.subcaption}]" else '') for graphic in graphics).join ' & '} = #{caption}"
        figure =
          graphics: graphics
          caption: caption
          labels: labels
        if labels.length > 1
          console.warn "Multiple labels will appear: #{labels.join ' / '}"
        for label in labels
          figures[label] = figure
        for graphic in figure.graphics
          for label in graphic.labels
            figures[label] = figure
        ''
    ## Find inlined \includegraphics outside of figures:
    for graphic in findIncludeGraphics tex, false
      oldName = graphic.filename
      findGraphicFile graphic
      inlineGraphics[oldName] =
      inlineGraphics[graphic.filename] =
        graphics: [graphic]

  title2section = (title) ->
    title[...title.indexOf ' ']  ## section number
  formatLabel = (label) ->
    "``#{label.replace /^fi?g:/, ''}''"

  ## Extract sections = top-level threads.
  for content in zip.file /\.tex$/
    await content.async('string').then defer tex
    ## Remove comments (to ignore \sections inside comments),
    ## and remove figures (already processed).
    tex = tex
    .replace /%.*$\n?/mg, ''
    .replace /\\begin\s*{(wrap)?figure}[^]*?\\end\s*{(wrap)?figure}\s*/g, ''
    tex = processCites tex
    depths = []
    start = null
    labels = {}
    links = {}
    messages = []
    figurecount = 0
    r = /\\(sub)*section\s*{((?:[^{}]|{[^{}]*})*)}|\\bibliography/g
    while (match = r.exec tex)?
      if start?
        now = new Date
        body = tex[start...match.index]
        body = body.replace /\\label{([^{}]*)}/g, (match, label) ->
          labels[label] = title2section title
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

    for message, i in messages
      ## First, find which figures are used in this message.
      ## We upload the figures before the message so that the message
      ## can easily hyperlink directly to the messages.
      attach = []
      message.body.replace /\\ref\s*{([^{}]*)}/g, (match, ref) ->
        attach.push figures[ref] if ref of figures
        ''
      for graphic in findIncludeGraphics message.body
        attach.push inlineGraphics[graphic.filename]
      ## Next, upload the used figures as messages, submessages, and/or
      ## files.  At this point, each figure root gets no parent, as we
      ## haven't created the message for the problem yet.
      attach = _.uniq attach  ## upload \ref'd figures only once each
      for figure in attach
        figure.files = []
        for graphic in figure.graphics
          filename = graphic.filename
          base = basename filename
          await zip.file(filename).async('arraybuffer').then defer buffer
          file = new File [buffer],
                   base,
                   type: ext2type[path2ext base]
                   lastModified: now
          file.creator = me
          file.created = now
          file.group = group
          file.graphic = graphic
          figure.files.push file
          await
            do (d = defer file.file2id) ->
              file.callback = (file2) ->
                d file2.uniqueIdentifier
            Files.resumable.addFile file
      for figure in attach
        figure.message =
          title:
            if figure.labels and figure.labels.length > 0
              "Figure #{(formatLabel label for label in figure.labels).join ' / '}"
            else  ## for inline graphics
              ''
          body: figure.caption ? ''
          format: 'latex'
          published: now
        rootFiles = (file for file in figure.files when file.graphic.subcaption == false)
        if rootFiles.length == 1
          figure.message.file = rootFiles[0].file2id
          figure.files = _.without figures.files, rootFiles[0]
        frevision = _.clone figure.message
        figure.message.creator = me
        figure.message.created = now
        frevision.updators = [me]
        frevision.updated = now
        await Meteor.call 'messageImport', group, null, figure.message, [frevision], defer error, figure.message._id
        throw error if error
      await
        for figure in attach
          for file in figure.files
            filerev =
              file: file.file2id
              format: 'latex'
              published: now
            if file.graphic.labels.length > 0
              filerev.title = "Figure " +
                (formatLabel label for label in file.graphic.labels).join " / "
            if file.graphic.subcaption
              filerev.body = file.graphic.subcaption
            filemsg = _.clone filerev
            filemsg.creator = me
            filemsg.created = now
            filerev.updators = [me]
            filerev.updated = now
            Meteor.call 'messageImport', group, figure.message._id, filemsg, [filerev],
              defer()  ## ignoring error
      ## With the files uploaded, we can hyperlink to them in the message.
      message.body = message.body
      .replace /\\ref\s*{([^{}]*)}/g, (match, ref) ->
        if ref of labels
          if labels[ref] of links
            "\\href{#{links[labels[ref]]}}{#{labels[ref]}}"
          else
            console.warn "\\ref{#{ref}} used before \\label{#{ref}} defined, so no link to the corresponding message; you might add it manually"
            labels[ref]
        else if ref of figures
          #formatLabel figures[ref].labels[figures[p1].labels.length-1]
          "\\href{coauthor:#{figures[ref].message._id}}{#{formatLabel ref}}"
        else
          console.warn "Unresolved #{match}"
          match
      .replace /\\includegraphics\s*(\[[^\[\]]*\]\s*)?{((?:[^{}]|{[^{}]*})*)}/g,
        (match, optional, filename) ->
          "\\includegraphics#{optional}{coauthor:#{inlineGraphics[filename].message._id}}"
      ## Now we can upload the message itself.
      revision = _.clone message
      revision.updated = revision.created
      delete revision.created
      revision.updators = [revision.creator]
      delete revision.creator
      await Meteor.call 'messageImport', group, null, message, [revision], defer error, message._id
      throw error if error
      links[title2section message.title] = "coauthor:#{message._id}"
      ## Finally, reparent the figures' root messages to be children
      ## of the main message for the problem.
      for figure in attach
        Meteor.call 'messageParent', figure.message._id, message._id

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
  sub = Meteor.subscribe 'messages.imported', group, ->
  done = 0
  for file in files
    reader = new FileReader
    reader.onload = (e) ->
      importer group, e.target.result
      done += 1
      if done == files.length
        sub.stop()
        console.log 'Import complete'
    reader["readAs#{importer.readAs}"] file
