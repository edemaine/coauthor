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

@importFiles = (group, files) ->
  for file in files
    reader = new FileReader
    reader.onload = (e) ->
      zip = new JSZip e.target.result

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
          content.type = ext2type[ext]
          files[filename] = content
          #blob = new Blob [content],
          #  type: ext2type[ext]
          #console.log filename, content.date, content.asArrayBuffer()

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
            else
              usedFiles[filename] = true  ## remove duplicates
        usedFiles = (filename for filename of usedFiles)

        revisions[0].format = message.format
        ## Message body is actually the rendered HTML.  To get markdown format,
        ## use last revision:
        message.body = revisions[revisions.length-1].body
        if id of deleted
          message.deleted = true
          revisions.push deleted[id]
        else
          message.deleted = false
        message.published = revisions[0].published = message.created
        message.authors = {}
        for revision in revisions
          for author in revision.updators[0]
            message.authors[revision.updators[0]] = revision.updated
        if true
          await Meteor.call 'messageImport', group, parent, message, revisions, defer error, idmap[id]
          throw error if error
        else
          idmap[id] = 'test'
        count += 1
        #return if count == 5

    reader.readAsArrayBuffer file
