cookie = require 'cookie'
url = require 'url'

# Simultaneous file access/locking seems to need more listeners than 10
require('events').EventEmitter.defaultMaxListeners = 50

fileRe = /^\/(\w+)$/

defaultContentType = 'application/octet-stream'

## Allow files to be embedded in other sites, e.g. Cocreate.
## Note that this still requires Coauthor authentication via cookies.
allowCors = '*'

## Mimicking vsivsi:file-collection http_access_server.coffee
WebApp.rawConnectHandlers.use '/file',
  Meteor.bindEnvironment (req, res, next) ->
    url = url.parse req.url, true
    req.query = url.query
    match = url.path.match fileRe
    unless req.method in ['GET', 'HEAD'] and match?
      return next()
    msgId = match[1]

    ## handle_auth()
    req.cookies = cookie.parse req.headers.cookie if req.headers.cookie?
    authToken = req.headers?['x-auth-token'] ? req.cookies?['X-Auth-Token']
    ## Coauthor will send a string 'null' X-Auth-Token cookie when not logged
    ## in.  We expect an undefined token for (bad) requests from elsewhere.
    if authToken? and authToken != 'null'
      user = Meteor.users?.findOne
        'services.resume.loginTokens':
          $elemMatch:
            hashedToken: Accounts?._hashLoginToken authToken
      unless user?
        res.writeHead 400
        return res.end "Invalid X-Auth-Token #{authToken}"
      username = "User '#{user.username}'"
    else
      ## Allow null user, and check below for anonymous access.
      user = null
      username = "Not-logged-in user"
      #res.writeHead 400
      #return res.end "Missing X-Auth-Token header/token"

    ## Map message -> file
    msg = Messages.findOne msgId
    ## Used to restrict to these fields, but also need authors, title, body
    ## to determine whether we can see the message, so just get everything.
    # fields:
    #   group: true
    #   file: true
    #   root: true  ## for messageRoleCheck
    unless msg? and msg.file and (req.gridFS = findFile msg.file)?
      res.writeHead 403
      ## Use same error message whether file exists or not, so don't leak info.
      #return res.end "Invalid file message ID: #{msgId}"
      return res.end "#{username} lacks read permissions for group of message/file #{msgId}"
    # The following allowed users to see files attached to messages that have
    # been deleted/unpublished, even though those messages can't be seen...
    # Debatable whether that would be a bug or feature.
    #unless messageRoleCheck(msg.group, msg, 'read', user) and (msg.group == req.gridFS.metadata.group or groupRoleCheck req.gridFS.metadata.group, 'read', user)
    unless canSee msg, false, user
      res.writeHead 403
      return res.end "#{username} lacks read permissions for group of message/file #{msgId}"

    ## get()
    headers =
      'Content-Type': 'text/plain'
      'Cache-Control': 'stale-while-revalidate'
      'Access-Control-Allow-Origin': allowCors
    if req.headers['if-modified-since']
      since = Date.parse req.headers['if-modified-since']  ## NaN if invaild
      if since and req.gridFS.uploadDate and (req.headers['if-modified-since'] == req.gridFS.uploadDate.toUTCString() or since >= req.gridFS.uploadDate.getTime())
        res.writeHead 304, headers
        return res.end()
    if req.headers['range']
      statusCode = 206  # partial data
      parts = req.headers['range'].replace(/bytes=/, "").split("-")
      start = parseInt(parts[0], 10)
      end = (if parts[1] then parseInt(parts[1], 10) else req.gridFS.length - 1)
      if (start < 0) or (end >= req.gridFS.length) or (start > end) or isNaN(start) or isNaN(end)
        headers['Content-Range'] = 'bytes ' + '*/' + req.gridFS.length
        res.writeHead 416, headers
        return res.end()
      chunksize = (end - start) + 1
      headers['Content-Range'] = 'bytes ' + start + '-' + end + '/' + req.gridFS.length
      headers['Accept-Ranges'] = 'bytes'
      headers['Content-Length'] = chunksize
      headers['Last-Modified'] = req.gridFS.uploadDate.toUTCString()
      unless req.method is 'HEAD'
        stream = Files.findOneStream(
          _id: req.gridFS._id
        ,
          range:
            start: start
            end: end
        )
    else
      statusCode = 200
      headers['Content-MD5'] = req.gridFS.md5
      headers['Content-Length'] = req.gridFS.length
      headers['Last-Modified'] = req.gridFS.uploadDate.toUTCString()
      unless req.method is 'HEAD'
        stream = Files.findOneStream { _id: req.gridFS._id }
    headers['Content-Type'] = req.gridFS.contentType or defaultContentType
    filename = encodeURIComponent(req.query.filename ? req.gridFS.filename)
    headers['Content-Disposition'] = "inline; filename=\"#{filename}\"; filename*=UTF-8''#{filename}"
    if (req.query.download and req.query.download.toLowerCase() == 'true') or req.query.filename
      headers['Content-Disposition'] = "attachment; filename=\"#{filename}\"; filename*=UTF-8''#{filename}"
    if req.query.cache and not isNaN(parseInt(req.query.cache))
      headers['Cache-Control'] = "max-age=" + parseInt(req.query.cache)+", private"
    if req.method is 'HEAD'
      res.writeHead 204, headers
      return res.end()
    if stream
      res.writeHead statusCode, headers
      stream.pipe(res)
        .on 'close', () ->
          res.end()
        .on 'error', (err) ->
          res.writeHead 500
          res.end err
    else
      res.writeHead 410
      res.end()
