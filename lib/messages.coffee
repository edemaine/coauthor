@Messages = new Mongo.Collection 'messages'
@MessagesDiff = new Mongo.Collection 'messages.diff'
@MessagesParent = new Mongo.Collection 'messages.parents'

if Meteor.isServer
  Meteor.publish 'messages', (group) ->
    check group, String
    if groupRoleCheck group, 'read', @userId
      Messages.find
        group: group

  Meteor.publish 'messages.diff', (message) ->
    MessagesDiff.find
      id: message

  ## Remove all editors on server start, so that we can restart listeners.
  Messages.find().forEach (message) ->
    if message.editing?.length
      Messages.update message._id,
        $unset: editing: ''

## @canRead check isn't necessary, as it's implied by Meteor.publish'd
## groups and messages.

@canPost = (group, parent) ->
  ## parent actually ignored
  groupRoleCheck group, 'post'

@canEdit = (message) ->
  ## Can edit message if an "author" (the creator or edited in the past),
  ## or if we have global edit privileges in this group.
  msg = Messages.findOne message
  Meteor.user()?.username of msg.authors or
  groupRoleCheck msg.group, 'edit'

@canSuper = (group) ->
  groupRoleCheck group, 'super'

@canImport = (group) -> canSuper group
@canSuperdelete = (message) ->
  canSuper message2group message

idle = 1000   ## one second

@message2group = (message) ->
  Messages.findOne(message).group

@findMessageParent = (message) ->
  parents = Messages.find
    children: message
  .fetch()
  switch parents.length
    when 0
      null
    when 1
      parents[0]
    else
      throw "Message #{message} has #{parents.length} parents! #{parents}"

## The following should be called directly only on the server;
## clients should use the corresponding method.
@_messageUpdate = (id, message, authors = null, old = null) ->
  ## authors is set only when internal to server, in which case we bypass
  ## authorization checks, which already happened in messageEditStart.
  unless authors?
    check Meteor.userId(), String  ## should be done by 'canEdit'
    authors = [Meteor.user().username]
    return unless canEdit id
  check message,
    #url: Match.Optional String
    title: Match.Optional String
    body: Match.Optional String
    format: Match.Optional String
    tags: Match.Optional [String]
    #children: Match.Optional [String]  ## must be set via messageParent
    #parent: Match.Optional String      ## use children, not parent
    published: Match.Optional Boolean
    deleted: Match.Optional Boolean

  ## Don't update if there aren't any actual differences.  Compare with 'old'
  ## if provided (in cases when it's already been fetched by the server);
  ## otherwise, load id from Messages.
  old = Messages.findOne id unless old?
  diff = false
  for own key of message
    if old[key] != message[key]
      diff = true
      break
  return unless diff

  now = new Date
  if message.published
    message.published = now
  for author in authors
    message["authors." + author] = now
  Messages.update id,
    $set: message
  for author in authors
    delete message["authors." + author]
  message.updators = authors
  message.updated = now
  message.id = id
  MessagesDiff.insert message
  id

_messageParent: (child, parent, position = null, oldParent = true, importing = false) ->
  ## oldParent is an internal option for server only; true means "search for/
  ## deal with old parent", while null means we assert there is no old parent.
  check Meteor.userId(), String  ## should be done by 'canEdit'
  check parent, String if parent?
  check position, Number if position?
  #check oldParent, Boolean
  #check importing, Boolean
  pmsg = Messages.findOne parent
  if canEdit child and canPost pmsg.group, parent
    if oldParent
      oldParent = findMessageParent child
      if oldParent?
        Messages.update oldParent,
          $pop: children: child
    if position?
      Messages.update parent,
        $push: children:
          $each: [child]
          $position: position
    else
      Messages.update parent,
        $push: children: child
    Messages.update child,
      $set: root: pmsg.root ? parent
    doc =
      child: child
      parent: parent
      position: position
      oldParent: oldParent
    if importing
      cmsg = Messages.findOne child
      doc.updator = cmsg.creator
      doc.updated = cmsg.created
    else
      doc.updator = Meteor.user().username
      doc.updated = new Date
    MessagesParent.insert doc

Meteor.methods
  messageUpdate: (id, message) -> _messageUpdate id, message

  messageNew: (group, parent = null, position = null) ->
    check Meteor.userId(), String  ## should be done by 'canPost'
    check parent, String if parent?
    check group, String
    if canPost group, parent
      now = new Date
      username = Meteor.user().username
      authors = {}
      authors[username] = now
      message =
        creator: username
        created: now
        authors: authors
        group: group
        #parent: parent         ## use children, not parent
        children: []
        published: false
        deleted: false
        title: ""
      if parent?
        pmsg = Messages.findOne parent
        message.root = pmsg.root ? parent
      id = Messages.insert message
      ## Prepare for MessagesDiff
      delete message.creator
      delete message.created
      delete message.authors
      delete message.children
      delete message.root
      message.id = id
      message.updators = [Meteor.user().username]
      message.updated = now
      MessagesDiff.insert message
      if parent?
        _messageParent id, parent, position, null  ## there's no old parent
      id

    ## Initial URL (short name) is the Mongo-provided ID.  User can edit later.
    #message.url = id
    #Messages.update id,
    #  $set:
    #    url: id
    #message

  messageParent: (child, parent, position = null) ->
    ## Notably, disabling oldParent search and importing options are not
    ## allowed from client, only internal to server.
    _messageParent id, parent, position

  messageEditStart: (id) ->
    check Meteor.userId(), String
    if canEdit id
      if Meteor.isServer
        old = Messages.findOne id
        return unless old?
        unless old.editing?.length
          ShareJS.initializeDoc id, old.body ? ''
          timer = null
          listener = Meteor.bindEnvironment (opData) ->
            Meteor.clearTimeout timer
            timer = Meteor.setTimeout ->
              doc = Meteor.wrapAsync(ShareJS.model.getSnapshot) id
              #console.log id, 'changed to', doc.snapshot
              msg = Messages.findOne id
              unless msg.body == doc.snapshot
                _messageUpdate id,
                  body: doc.snapshot
                , msg.editing, msg
              #Messages.update id,
              #  $set: body: doc.snapshot
              #MessagesDiff.insert
              #  id: id
              #  updators: msg.editing
              #  updated: new Date
              #  body: doc.snapshot
            , idle
          ShareJS.model.listen id, listener
      Messages.update id,
        $addToSet: editing: Meteor.user().username

  messageEditStop: (id) ->
    check Meteor.userId(), String
    Messages.update id,
      $pull: editing: Meteor.user().username
    #after = Messages.findAndModify
    #  query: id
    #  update: update
    #  new: true
    #console.log after
    #if Meteor.isServer and (after.editing ? []).length == 0
    if Meteor.isServer
      unless Messages.findOne(id).editing?.length
        ShareJS.model.delete id

  messageImport: (group, parent, message, diffs) ->
    check Meteor.userId(), String  ## should be done by 'canImport'
    check group, String
    check parent, String if parent?
    check message,
      title: Match.Optional String
      body: Match.Optional String
      format: Match.Optional String
      tags: Match.Optional [String]
      #children: Match.Optional [String]  ## must be set via messageParent
      #parent: Match.Optional String      ## use children, not parent
      published: Match.Optional Match.OneOf Date, Boolean
      deleted: Match.Optional Boolean
      creator: Match.Optional String
      created: Match.Optional Date
      authors: Match.Any
    check diffs, [
      title: Match.Optional String
      body: Match.Optional String
      format: Match.Optional String
      tags: Match.Optional [String]
      updated: Match.Optional Date
      updators: Match.Optional [String]
    ]
    if canImport group
      now = new Date
      if message.published == true
        message.published = now
      message.group = group
      message.children = []
      message.importer = Meteor.user().username
      message.imported = now
      if parent?
        pmsg = Messages.findOne parent
        message.root = pmsg.root ? parent
      id = Messages.insert message
      for diff in diffs
        diff.id = id
        diff.group = group
        MessagesDiff.insert diff
      if parent?
        _messageParent id, parent, null, null, true
      id

  messageSuperdelete: (message) ->
    ## xxx doesn't remove stuff from MessagesParent or MessagesDiff logs
    check message, String
    if canSuperdelete message
      msg = Messages.findOne message
      return unless msg?
      Messages.remove message
      children = msg.children
      parent = findMessageParent message
      if parent?
        Messages.update parent._id,
          $pull: children: message
        Messages.update parent._id,
          $push: children:
            $each: children
            $position: parent.children.indexOf message
        ## children roots remain the same
      else
        for child in children
          Messages.update child,
            $unset: root: ''
