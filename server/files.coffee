cookie = require 'cookie'
url = require 'url'

fileRe = /^\/(\w+)$/

defaultContentType = 'application/octet-stream'

## Mimicking vsivsi:file-collection http_access_server.coffee
WebApp.rawConnectHandlers.use '/file',
  Meteor.bindEnvironment (req, res, next) ->
    url = url.parse req.url, true
    req.query = url.query
    match = url.path.match fileRe
    unless req.method in ['GET', 'HEAD'] and match?
      return next()

    ## handle_auth()
    req.cookies = cookie.parse req.headers.cookie if req.headers.cookie?
    authToken = req.headers?['x-auth-token'] ? req.cookies?['X-Auth-Token']
    unless authToken?
      res.writeHead 400
      return res.end "Missing X-Auth-Token header/token"
    user = Meteor.users?.findOne
      'services.resume.loginTokens':
        $elemMatch:
          hashedToken: Accounts?._hashLoginToken authToken
    unless user?
      res.writeHead 400
      return res.end "Invalid X-Auth-Token #{authToken}"

    ## Map message -> file
    msg = Messages.findOne match[1],
      fields:
        group: true
        file: true
        root: true  ## for messageRoleCheck
    unless msg? and msg.file and (req.gridFS = findFile msg.file)?
      res.writeHead 403
      return res.end "Invalid file message ID: #{match[1]}"
    unless messageRoleCheck(msg.group, msg, 'read', user) and (msg.group == req.gridFS.metadata.group or groupRoleCheck req.gridFS.metadata.group, 'read', user)
      res.writeHead 401
      return res.end "Lack read permissions for group of message/file #{match[1]}"

    ## get()
    headers =
      'Content-Type': 'text/plain'
    if req.headers['if-modified-since']
      since = Date.parse req.headers['if-modified-since']  ## NaN if invaild
      if since and req.gridFS.uploadDate and (req.headers['if-modified-since'] == req.gridFS.uploadDate.toUTCString() or since >= req.gridFS.uploadDate.getTime())
        res.writeHead 304, headers
        return res.end()
    if req.headers['range']
      statusCode = 206  # partial data
      parts = req.headers["range"].replace(/bytes=/, "").split("-")
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
          res.writeHead 500, share.defaultResponseHeaders
          res.end err
    else
      res.writeHead 410, share.defaultResponseHeaders
      res.end()
