@Messages = new Mongo.Collection 'messages'
@MessagesDiff = new Mongo.Collection 'messages.diff'
@MessagesParent = new Mongo.Collection 'messages.parents'

if Meteor.isServer
  Meteor.publish 'messages', (group) ->
    check group, String
    @autorun ->
      user = findUser @userId
      ## Mimic logic of `canSee` below.
      if groupRoleCheck group, 'super', user
        ## Super-user can see all messages, even unpublished/deleted messages.
        Messages.find
          group: group
      else if groupRoleCheck group, 'read', user
        ## Regular users can see all messages they authored, plus
        ## published undeleted messages by others.
        if user?.username
          Messages.find
            $and: [
              group: group
            , $or: [
                published: $ne: false    ## published is false or Date
                deleted: false
              , "authors.#{escapeUser user.username}": $exists: true
              ]
            ]  ## if you change this, change message.coffee's children helper
        else
          Messages.find
            group: group
            published: $ne: false    ## published is false or Date
            deleted: false
      else
        @ready()

  Meteor.publish 'messages.diff', (message) ->
    check message, String
    @autorun ->
      if canSee message, false, findUser @userId
        MessagesDiff.find
          id: message
      else
        @ready()

  ## Remove all editors on server start, so that we can restart listeners.
  Messages.find().forEach (message) ->
    if message.editing?.length
      Messages.update message._id,
        $unset: editing: ''

@canSee = (message, client = Meteor.isClient, user = Meteor.user()) ->
  ## Visibility of a message is implied by its existence in the Meteor.publish
  ## above, so we don't need to check this in the client.  But this function
  ## is still needed in the server for messages.diff subscription above,
  ## and when simulating non-superuser mode in client/message.coffee.
  message = Messages.findOne message unless message._id?
  group = message.group #message2group message
  if canSuper group, client, user #groupRoleCheck group, 'super', user
    ## Super-user can see all messages, even unpublished/deleted messages.
    true
  else if groupRoleCheck group, 'read', user
    ## Regular users can see all messages they authored, plus
    ## published undeleted messages by others.
    (message.published and not message.deleted) or
    user.username of (message.authors ? {})
  else
    false

@canPost = (group, parent) ->
  ## parent actually ignored
  Meteor.userId()? and
  groupRoleCheck group, 'post'

@canEdit = (message) ->
  ## Can edit message if an "author" (the creator or edited in the past),
  ## or if we have global edit privileges in this group.
  msg = Messages.findOne message
  escapeUser(Meteor.user()?.username) of (msg.authors ? {}) or
  groupRoleCheck msg.group, 'edit'

@canDelete = canEdit
@canUndelete = canEdit
@canPublish = canEdit

@canUnpublish = (message) ->
  canSuper message2group message

@canSuper = (group, client = Meteor.isClient, user = Meteor.user()) ->
  ## If client is true, we use the session variable 'super' to fake whether
  ## superuser mode is viewed as on (from the client perspective).
  ## This lets someone with superuser permissions pretend to be normal.
  (not client or Session.get 'super') and
  groupRoleCheck group, 'super', user

@canImport = (group) -> canSuper group
@canSuperdelete = (message) ->
  canSuper message2group message

@canAdmin = (group) ->
  groupRoleCheck group, 'admin'

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

@messageEmpty = (message) ->
  message = Messages.findOne message unless message._id?
  message.title.trim().length == 0 and
  message.body.trim().length == 0

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
  if message.published == true
    message.published = now
  for author in authors
    message["authors." + escapeUser author] = now
  Messages.update id,
    $set: message
  for author in authors
    delete message["authors." + escapeUser author]
  message.updators = authors
  message.updated = now
  message.id = id
  diffid = MessagesDiff.insert message
  message._id = diffid
  notifyMessageUpdate message if Meteor.isServer  ## client in simulation
  diffid

_messageParent = (child, parent, position = null, oldParent = true, importing = false) ->
  ## oldParent is an internal option for server only; true means "search for/
  ## deal with old parent", while null means we assert there is no old parent.
  check Meteor.userId(), String  ## should be done by 'canEdit'
  check parent, String if parent?
  check position, Number if position?
  #check oldParent, Boolean
  #check importing, Boolean
  pmsg = Messages.findOne parent
  if canEdit(child) and canPost pmsg.group, parent
    cmsg = Messages.findOne child
    unless cmsg.root
      throw "Attempt to reparent root message #{child}"
      ## To support this case, we'd need to change the root of all descendants.
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
      #cmsg = Messages.findOne child
      doc.updator = cmsg.creator
      doc.updated = cmsg.created
    else
      doc.updator = Meteor.user().username
      doc.updated = new Date
    MessagesParent.insert doc

if Meteor.isServer
  editorTimers = {}

  editor2messageUpdate = (id) ->
    Meteor.clearTimeout editorTimers[id]
    doc = Meteor.wrapAsync(ShareJS.model.getSnapshot) id
    #console.log id, 'changed to', doc.snapshot
    msg = Messages.findOne id
    unless msg.body == doc.snapshot
      _messageUpdate id,
        body: doc.snapshot
      , msg.editing, msg

  delayedEditor2messageUpdate = (id) ->
    Meteor.clearTimeout editorTimers[id]
    editorTimers[id] = Meteor.setTimeout ->
      editor2messageUpdate id
    , idle

Meteor.methods
  messageUpdate: (id, message) -> _messageUpdate id, message

  messageNew: (group, parent = null, position = null, message = {}) ->
    check Meteor.userId(), String  ## should be done by 'canPost'
    check parent, String if parent?
    check position, Number if position?
    check group, String
    check message,
      title: Match.Optional String
      body: Match.Optional String
      format: Match.Optional String
      tags: Match.Optional [String]
      #children: Match.Optional [String]  ## must be set via messageParent
      #parent: Match.Optional String      ## use children, not parent
      published: Match.Optional Boolean
      deleted: Match.Optional Boolean

    if canPost group, parent
      now = new Date
      username = Meteor.user().username
      message.creator = username
      message.created = now
      message.authors =
        "#{escapeUser username}": now
      message.group = group
      #message.parent: parent         ## use children, not parent
      message.children = []
      ## Default content.
      message.title = "" unless message.title?
      message.body = "" unless message.body?
      message.format = Meteor.user()?.profile?.format or defaultFormat unless message.format?
      message.tags = [] unless message.tags?
      message.published = autopublish() unless message.published?
      if message.published == true
        message.published = now
      message.deleted = false unless message.deleted?
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
            delayedEditor2messageUpdate id
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
        editor2messageUpdate id
        ShareJS.model.delete id
    ## xxx should add to last MessagesDiff (possibly just made) that
    ## Meteor.user().username just committed this version.

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
    check diffs, [
      title: Match.Optional String
      body: Match.Optional String
      format: Match.Optional String
      tags: Match.Optional [String]
      deleted: Match.Optional Boolean
      updated: Match.Optional Date
      updators: Match.Optional [String]
      published: Match.Optional Match.OneOf Date, Boolean
    ]
    if canImport group
      now = new Date
      me = Meteor.user().username
      if message.published == true
        message.published = now
      message.group = group
      message.children = []
      message.importer = me
      message.imported = now
      ## Automatically set 'authors' to have the latest update for each author.
      message.authors = {}
      for diff in diffs
        for author in diff.updators
          message.authors[author] = diff.updated
      if parent?
        pmsg = Messages.findOne parent
        message.root = pmsg.root ? parent
      id = Messages.insert message
      for diff in diffs
        diff.id = id
        diff.group = group
        diff.importer = me
        diff.imported = now
        MessagesDiff.insert diff
      if parent?
        _messageParent id, parent, null, null, true
      id

  messageSuperdelete: (message) ->
    check message, String
    if canSuperdelete message
      user = Meteor.user().username
      now = new Date
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
        for child, i in children
          MessagesParent.insert
            child: child
            position: i + parent.children.indexOf message
            parent: parent
            updator: user
            updated: now
      else
        for child in children
          Messages.update child,
            $unset: root: ''
      ## Delete all associated files.
      MessagesDiff.find
        id: message
      .forEach (diff) ->
        if diff.format == 'file'
          deleteFile diff.body
      ## Delete all diffs for this message.
      MessagesDiff.remove
        id: message
      ## Delete all parent references to this message.
      ## 
      MessagesParent.remove
        $or: [
          child: message
        , parent: message
        ]

  recomputeAuthors: ->
    ## Force recomputation of all `authors` fields to be the latest update
    ## for each updator.
    if canSuper wildGroup
      Messages.find({}).forEach (msg) ->
        authors = {}
        MessagesDiff.find
          id: msg._id
        .forEach (diff) ->
          for updator in diff.updators
            updated = diff.updated
            escape = escapeUser updator
            if escape not of authors or authors[escape].getTime() < updated.getTime()
              authors[escape] = updated
        Messages.update msg._id,
          $set: authors: authors
