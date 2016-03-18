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

importLaTeX = (group, tex) ->
  me = Meteor.user().username
  ## Remove comments (to ignore \sections inside comments).
  ## Also remove figures, as we're not handling that yet...
  tex = tex
  .replace /%.*$\n?/mg, ''
  .replace /\\begin{figure}[^\0]*?\\end{figure}\s*/g, ''
  .replace /\\begin{wrapfigure}[^\0]*?\\end{wrapfigure}\s*/g, ''
  .replace /\\begin{wrapfigure}[^\0]*?\\end{wrapfigure}\s*/g, ''
  ## xxx \ref, \cite
  r = /\\(sub)*section\s*{((?:[^{}]|{[^{}]*})*)}|\\bibliography/g
  depths = []
  start = null
  labels = {}
  messages = []
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
    message.body = message.body
    .replace /\\ref{([^{}]*)}/, (match, p1) ->
      if p1 of labels
        labels[p1]
      else
        match
    revision = _.clone message
    revision.updated = revision.created
    delete revision.created
    revision.updators = [revision.creator]
    delete revision.creator
    Meteor.call 'messageImport', group, null, message, [revision]

importLaTeX.readAs = 'Text'

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
