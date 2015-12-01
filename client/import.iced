parseXML = (zipdata) ->
  xml = zipdata.asText()
  xml = xml.replace /\x0C/g, 'fi'  ## must be from some LaTeX copy/paste...
  xml = $($.parseXML xml)

bodymap = (body) ->
  ## Turn $$ into $ to convert to new MathJax format.
  body.replace /\$\$/g, '$'

@importFiles = (group, files) ->
  for file in files
    reader = new FileReader
    reader.onload = (e) ->
      zip = new JSZip e.target.result
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
        ## Message body is actually the rendered HTML.  To get markdown format,
        ## use last revision:
        message.body = revisions[revisions.length-1].body
        message.published = message.created
        message.deleted = false  ## deleted messages seem not to be in export
        message.authors = {}
        for revision in revisions
          for author in revision.updators[0]
            message.authors[revision.updators[0]] = revision.updated
        await Meteor.call 'messageImport', group, parent, message, revisions, defer error, idmap[id]
        throw error if error
        count += 1
        #return if count == 5
    reader.readAsArrayBuffer file