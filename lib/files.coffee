import {check, Match} from 'meteor/check'
import {Accounts} from 'meteor/accounts-base'

###
corsHandler = (req, res, next) ->
  if req.headers?.origin
    res.setHeader 'Access-Control-Allow-Origin', req.headers.origin
    res.setHeader 'Access-Control-Allow-Credentials', true
  next()
###

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
  Files.createIndex [
    ['metadata.group', 1]
    ['metadata._Resumable', 1]
  ]

export messageFileUrlPrefix = "/file/"
export messageFileAbsoluteUrlPrefix = Meteor.absoluteUrl messageFileUrlPrefix[1..]
export internalFileUrlPrefix = "#{Files.baseURL}/id/"
export internalFileAbsoluteUrlPrefix = Meteor.absoluteUrl internalFileUrlPrefix[1..]
export fileUrlPrefixPattern =
  "(?:(#{messageFileUrlPrefix}|#{messageFileAbsoluteUrlPrefix})|" +
   "(#{internalFileUrlPrefix}|#{internalFileAbsoluteUrlPrefix}))"
export messageFileUrlPrefixPattern =
  "(?:#{messageFileUrlPrefix}|#{messageFileAbsoluteUrlPrefix})"

## If given object has a `file` and either a `diffId` field or no `_id` field,
## then we make a link to the internal file object instead of the file
## associated with a message.  This lets History work with files.
@urlToFile = (id) ->
  if id.diffId? or (id.file? and not id._id?)
    urlToInternalFile id
  else
    "#{messageFileAbsoluteUrlPrefix}#{id._id ? id}"

@url2file = (url) ->
  for prefix in [messageFileUrlPrefix, messageFileAbsoluteUrlPrefix]
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
  @readableFiles = (userId) ->
    Files.find
      'metadata._Resumable': $exists: false
      'metadata.group': $in: accessibleGroupNames userId

  Meteor.publish 'files', (group) ->
    check group, String
    @autorun ->
      if groupVisible group, findUser @userId
        Files.find
          'metadata._Resumable': $exists: false
          'metadata.group': group
      else
        @ready()
        ## This was a bit of a hack for groups with anonymous write-only access
        ## so that you can at least see files that you uploaded.
        ## But that case is now included in `groupVisible`.
        #Files.find
        #  'metadata._Resumable': $exists: false
        #  'metadata.group': group
        #  'metadata.uploader': @userId

  ## User can read or upload a file if they have read or post permission
  ## respectively, either in the group or for any thread within the group.
  fileRoleCheck = (file, role, userId) ->
    group = file.metadata?.group ? wildGroup
    user = findUser userId
    rootRoleCheck group, file.metadata?.root, role, user

  Files.allow
    insert: (userId, file) ->
      check file?.metadata,
        group: Match.Optional String
        root: Match.Optional String
      file.metadata.uploader = userId
      fileRoleCheck file, 'post', userId
    read: (userId, file) ->
      #file.metadata?.uploader == userId or
      fileRoleCheck file, 'read', userId
    remove: (userId, file) ->
      ## Support `deleteFile` which calls `Files.remove` which goes over socket.
      ## This sets Meteor.userId but meteor-file-collection
      ## just checks X-Auth-Token
      userId ?= Meteor.user()
      #file.metadata?.uploader == userId
      fileRoleCheck file, 'super', userId
else
  Cookies = require 'js-cookie'

  Tracker.autorun ->
    Meteor.userId()  ## rerun when userId changes
    if Meteor.isCordova
      window.cookieEmperor.setCookie Meteor.absoluteUrl(),
        'X-Auth-Token', Accounts._storedLoginToken()
    else
      options = path: '/'
      if Meteor.absoluteUrl().startsWith 'https'
        options.secure = true
        options.sameSite = 'None'
      Cookies.set 'X-Auth-Token', Accounts._storedLoginToken(), options

  Session.set 'uploading', {}
  updateUploading = (changer) =>
    uploading = Session.get 'uploading'
    changer.call uploading
    Session.set 'uploading', uploading

  Files.resumable.on 'fileAdded', (file) =>
    file.metadata = file.file.metadata
    updateUploading -> @[file.uniqueIdentifier] =
      filename: file.fileName
      progress: 0
    Files.resumable.upload()

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

# client-only export
export updateUploading = updateUploading
