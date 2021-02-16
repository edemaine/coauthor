#userInfo = ->
#  fetch "https://api.dropbox.com/1/account/info",
#    headers: Authorization: "Bearer #{user.services.dropbox.accessToken}"

README = '''
This directory is maintained by Coauthor (https://coauthor.csail.mit.edu).
'''

dropboxFilename = (file) ->
  filename = file.filename
  dot = filename.lastIndexOf '.'
  file.metadata.group + '/' +
    if dot >= 0
      "#{filename[...dot]}[#{file._id._str}]#{filename[dot..]}"
    else
      "#{filename}[#{file._id._str}]"

class Dropbox
  constructor: (@user) ->
  headers: ->
    Authorization: "Bearer #{@user.services.dropbox.accessToken}"
  writeFile: (path, content) ->
    while path[0] == '/'
      path = path[1..]
    fetch "https://content.dropboxapi.com/1/files_put/auto/#{path}",
      method: 'PUT'
      headers: @headers()
      body: content
  writeReadme: ->
    @writeFile 'README.txt', README
  mkdir: (path) ->
    fetch 'https://api.dropboxapi.com/1/fileops/create_folder',
      method: 'POST'
      headers: @headers()
      body: "root=auto&path=#{encodeURIComponent path}"
    .catch (error) -> null
  makeGroupDirs: ->
    for group in memberOfGroups @user
      @mkdir group
  writeFiles: ->
    readableFiles(@user._id).forEach (file) =>
      stream = Files.findOneStream file._id
      ## The following loads files entirely into memory...  For giant files,
      ## it would be better to spread this out over multiple operations,
      ## using the stream of an HTTP PUT request.
      buffers = []
      stream.on 'data', (chunk) -> buffers.push chunk
      stream.on 'end', Meteor.bindEnvironment =>
        data = Buffer.concat buffers
        @writeFile dropboxFilename(file), data
  delta: (cursor) ->
    fetch 'https://api.dropboxapi.com/1/delta',
      method: 'POST'
      headers: @headers()
      body:
        if cursor?
          "cursor=#{encodeURIComponent cursor}"
        else
          ''

### eslint-disable coffee/no-unreachable ###
Meteor.startup ->
  return  ## temporary
  Meteor.users.find
    'services.dropbox.accessToken': $exists: 1
  .forEach (user) ->
    dropbox = new Dropbox user
    dropbox.writeReadme()
    dropbox.makeGroupDirs()
    dropbox.writeFiles()
    #console.log dropbox.delta().data.entries[0]
  #Meteor.users.observe
