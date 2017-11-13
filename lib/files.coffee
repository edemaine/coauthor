corsHandler = (req, res, next) ->
  if req.headers?.origin
    res.setHeader 'Access-Control-Allow-Origin', req.headers.origin
    res.setHeader 'Access-Control-Allow-Credentials', true
  next()

@Files = new FileCollection
  resumable: true
  resumableIndexName: 'files'
  http: [
    method: 'get'
    path: '/id/:_id'
    lookup: (params, query) ->
      _id: params._id
  #  handler: corsHandler
  #,
  #  method: 'post'
  #  path: '/_resumable'
  #  lookup: -> {}   ## INCORRECT
  #  handler: corsHandler
  #,
  #  method: 'head'
  #  path: '/_resumable'
  #  lookup: -> {}
  #  handler: corsHandler
  #,
  #  method: 'options'
  #  path: '/_resumable'
  #  lookup: -> {}
  #  handler: (req, res, next) ->
  #    res.writeHead 200,
  #      'Content-Type': 'text/plain'
  #      'Access-Control-Allow-Origin': req.headers.origin
  #      'Access-Control-Allow-Credentials': true
  #      'Access-Control-Allow-Headers': 'x-auth-token, user-agent'
  #      'Access-Control-Allow-Methods': 'GET, POST, HEAD, OPTIONS'
  #    res.end()
  ]

if Meteor.isServer
  Files._ensureIndex [
    ['metadata.group', 1]
    ['metadata._Resumable', 1]
  ]

@fileUrlPrefix = "/file/"

## If given object has a `file` but no `_id` field, then we make a link
## to the internal file object instead of the file associated with a message.
## This lets History work with files.
@urlToFile = (id) ->
  id = id._id if id._id?
  if id.file?
    urlToInternalFile id
  else
    Meteor.absoluteUrl "#{fileUrlPrefix[1..]}#{id}"

@url2file = (url) ->
  if url[...fileUrlPrefix.length] == fileUrlPrefix
    url[fileUrlPrefix.length..]
  else
    absolutePrefix = Meteor.absoluteUrl fileUrlPrefix[1..]
    if url[...absolutePrefix.length] == absolutePrefix
      url[absolutePrefix.length..]
    else
      throw new Meteor.Error 'url2file.invalid',
        "Bad file URL #{url}"

@internalFileUrlPrefix = "#{Files.baseURL}/id/"

@urlToInternalFile = (id) ->
  id = id.file if id.file?
  Meteor.absoluteUrl "#{internalFileUrlPrefix[1..]}#{id}"

@url2internalFile = (url) ->
  if url[...internalFileUrlPrefix.length] == internalFileUrlPrefix
    url[internalFileUrlPrefix.length..]
  else
    absolutePrefix = Meteor.absoluteUrl internalFileUrlPrefix[1..]
    if url[...absolutePrefix.length] == absolutePrefix
      url[absolutePrefix.length..]
    else
      throw new Meteor.Error 'url2internalFile.invalid',
        "Bad file URL #{url}"

@findFile = (id) ->
  Files.findOne new Meteor.Collection.ObjectID id
@deleteFile = (id) ->
  Files.remove new Meteor.Collection.ObjectID id

@fileType = (file) ->
  file = findFile file unless file.contentType?
  if file?.contentType in ['image/gif', 'image/jpeg', 'image/png', 'image/svg+xml', 'image/webp', 'image/x-icon']
    'image'
  else if file?.contentType in ['video/mp4', 'video/ogg', 'video/webm']
    'video'
  else
    'unknown'

if Meteor.isServer
  @readableFiles = (userid) ->
    Files.find
      'metadata._Resumable': $exists: false
      #$or:
      #  'metadata.updator': @userId
      'metadata.group': $in: readableGroupNames userid

  Meteor.publish 'files', (group) ->
    check group, String
    @autorun ->
      if groupRoleCheck group, 'read', findUser @userId
        Files.find
          'metadata._Resumable': $exists: false
          'metadata.group': group
      else
        @ready()

  Files.allow
    insert: (userId, file) ->
      file.metadata = {} unless file.metadata?
      check file.metadata,
        group: Match.Optional String
      file.metadata.uploader = userId
      groupRoleCheck file.metadata.group ? wildGroup, 'post', findUser userId
    remove: (userId, file) ->
      file.metadata?.uploader in [userId, null]
    read: (userId, file) ->
      file.metadata?.uploader in [userId, null] or
      groupRoleCheck file.metadata?.group, 'read', findUser userId
    write: (userId, file, fields) ->
      file.metadata?.uploader in [userId, null]
else
  Tracker.autorun ->
    Meteor.userId()  ## rerun when userId changes
    if Meteor.isCordova
      window.cookieEmperor.setCookie Meteor.absoluteUrl(),
        'X-Auth-Token', Accounts._storedLoginToken()
    else
      $.cookie 'X-Auth-Token', Accounts._storedLoginToken(),
        path: '/'

  Session.set 'uploading', {}
  updateUploading = (changer) =>
    uploading = Session.get 'uploading'
    changer.call uploading
    Session.set 'uploading', uploading

  Files.resumable.on 'fileAdded', (file) =>
    updateUploading -> @[file.uniqueIdentifier] =
      filename: file.fileName
      progress: 0
    Files.insert
      _id: file.uniqueIdentifier    ## This is the ID resumable will use.
      filename: file.fileName
      contentType: file.file.type
      metadata:
        group: file.file.group
    , (err, _id) =>
      if err
        console.error "File creation failed:", err
      else
        ## Once the file exists on the server, start uploading.
        Files.resumable.upload()  ## xxx couldn't this upload the wrong file(s)?

  Files.resumable.on 'fileProgress', (file) =>
    updateUploading -> @[file.uniqueIdentifier].progress = Math.floor 100*file.progress()
  Files.resumable.on 'fileSuccess', (file) ->
    updateUploading -> delete @[file.uniqueIdentifier]
    if _.keys(Session.get 'uploading').length == 0
      window.dispatchEvent new Event 'filesDone'
    file.file.callback?(file)
  Files.resumable.on 'fileError', (file) ->
    console.error "Error uploading", file.uniqueIdentifier
    updateUploading -> delete @[file.uniqueIdentifier]
