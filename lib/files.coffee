@Files = FileCollection
  resumable: true
  resumableIndexName: 'files'
  http: [
    method: 'get'
    path: '/id/:_id'
    lookup: (params, query) ->
      console.log params, query
      console.log params._id
      _id: params._id
  ]

if Meteor.isServer
  Meteor.publish 'files', (userId) ->
    ## This prevents a race condition on the client between Meteor.userId() and subscriptions to this publish
    ## See: https://stackoverflow.com/questions/24445404/how-to-prevent-a-client-reactive-race-between-meteor-userid-and-a-subscription/24460877#24460877
    if @userId is userId
      Files.find
        'metadata._Resumable': $exists: false
        'metadata.updator': @userId
    else
      @ready()

  Files.allow
    insert: (userId, file) ->
      file.metadata = {} unless file.metadata?
      file.metadata.uploader = userId
      userId?   ## xxx AUTHENTICATE
    remove: (userId, file) ->
      file.metadata?.uploader == userId
    read: (userId, file) ->
      file.metadata?.uploader == userId
    write: (userId, file, fields) ->
      #console.log file, userId
      file.metadata?.uploader == userId
else
  Tracker.autorun ->
    Meteor.subscribe 'files', Meteor.userId()
    $.cookie 'X-Auth-Token', Accounts._storedLoginToken()

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
    file.file.callback?()
  Files.resumable.on 'fileError', (file) ->
    console.error "Error uploading", file.uniqueIdentifier
    updateUploading -> delete @[file.uniqueIdentifier]
