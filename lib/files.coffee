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
@fileAbsoluteUrlPrefix = Meteor.absoluteUrl fileUrlPrefix[1..]
@internalFileUrlPrefix = "#{Files.baseURL}/id/"
@internalFileAbsoluteUrlPrefix = Meteor.absoluteUrl internalFileUrlPrefix[1..]
@fileUrlPattern =
  "(?:(#{fileUrlPrefix}|#{fileAbsoluteUrlPrefix})|" +
   "(#{internalFileUrlPrefix}|#{internalFileAbsoluteUrlPrefix}))"

## If given object has a `file` and either a `diffId` field or no `_id` field,
## then we make a link to the internal file object instead of the file
## associated with a message.  This lets History work with files.
@urlToFile = (id) ->
  if id.diffId? or (id.file? and not id._id?)
    urlToInternalFile id
  else
    "#{fileAbsoluteUrlPrefix}#{id._id ? id}"

@url2file = (url) ->
  for prefix in [fileUrlPrefix, fileAbsoluteUrlPrefix]
    if url[...prefix.length] == prefix
      return url[prefix.length..]
  throw new Meteor.Error 'url2file.invalid', "Bad file URL #{url}"

@urlToInternalFile = (id) ->
  id = id.file if id.file?
  "#{internalFileAbsoluteUrlPrefix}#{id}"

@url2internalFile = (url) ->
  for prefix in [internalFileUrlPrefix, internalFileAbsoluteUrlPrefix]
    if url[...prefix.length] == prefix
      return url[prefix.length..]
  throw new Meteor.Error 'url2internalFile.invalid', "Bad file URL #{url}"

@findFile = (id) ->
  Files.findOne new Meteor.Collection.ObjectID id
@deleteFile = (id) ->
  Files.remove new Meteor.Collection.ObjectID id

@fileType = (file) ->
  file = findFile file unless file.contentType?
  switch file?.contentType
    when 'image/gif', 'image/jpeg', 'image/png', 'image/svg+xml', 'image/webp', 'image/x-icon'
      'image'
    when 'video/mp4', 'video/ogg', 'video/webm'
      'video'
    when 'application/pdf'
      'pdf'
    else
      'unknown'

if Meteor.isServer
  @readableFiles = (userid) ->
    Files.find
      'metadata._Resumable': $exists: false
      #$or:
      #  'metadata.updator': @userId
      'metadata.group': $in: accessibleGroupNames userid

  Meteor.publish 'files', (group) ->
    check group, String
    @autorun ->
      if memberOfGroupOrReadable group, findUser @userId
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
      memberOfGroup file.metadata.group ? wildGroup, findUser userId
    remove: (userId, file) ->
      file.metadata?.uploader == userId
    read: (userId, file) ->
      file.metadata?.uploader == userId or
      memberOfGroup file.metadata?.group, findUser userId
    write: (userId, file, fields) ->
      file.metadata?.uploader == userId
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
    ## Mark file as completed *after* callback succeeds, if it's provided.
    updateUploading -> @[file.uniqueIdentifier].progress = 100
    completed = (error, result) =>
      updateUploading -> delete @[file.uniqueIdentifier]
      if _.keys(Session.get 'uploading').length == 0
        window.dispatchEvent new Event 'filesDone'
      if error
        console.error "Error in upload callback: #{error}"
    if file.file.callback?
      file.file.callback file, completed
    else
      completed()
  Files.resumable.on 'fileError', (file) ->
    console.error "Error uploading", file.uniqueIdentifier
    updateUploading -> delete @[file.uniqueIdentifier]
