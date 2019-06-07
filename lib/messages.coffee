import { defaultFormat } from './settings.coffee'
import { ShareJS } from 'meteor/edemaine:sharejs'

@untitledMessage = '(untitled)'

@titleOrUntitled = (msg) ->
  unless msg?
    null
  else if not msg.title? or msg.title.trim().length == 0
    if msg.file and (file = findFile msg.file)
      file.filename
    else
      untitledMessage
  else
    msg.title

@angle180 = (a) ->
  while a > 180
    a -= 360
  while a <= -180
    a += 360
  a

@Messages = new Mongo.Collection 'messages'
@MessagesDiff = new Mongo.Collection 'messages.diff'
@MessagesParent = new Mongo.Collection 'messages.parents'

if Meteor.isServer
  #Messages._ensureIndex group: 'hashed'
  ## This index makes it easy to find all messages in a specified group,
  ## and to find all root (root = null) messages in a specified group.
  Messages._ensureIndex [
    ['group', 1]
    ['root', 1]
  ]
  ## This index makes it easy to find all submessages within a given root.
  Messages._ensureIndex [
    ['root', 1]
  ]
  ## This index is for the 'live' and 'since' query:
  ## most recent messages in a group.
  Messages._ensureIndex [
    ['group', 1]
    ['updated', -1]
  ]
  ## This index makes findMessageParent fast.
  Messages._ensureIndex [
    ['children', 1]
  ]

@rootMessages = (group) ->
  query =
    root: null
  if group?
    query.group = group
  Messages.find query

## Works from nonroot messages via recursion.  Doesn't include message itself.
@descendantMessageIds = (message) ->
  descendants = []
  recurse = (m) ->
    m = findMessage m
    for child in m.children
      descendants.push child
      recurse child
  recurse message
  descendants

@ancestorMessages = (message, self = false) ->
  if self and message?
    yield findMessage message
  loop
    message = findMessageParent message
    break unless message?
    yield message

## Recompute this every time to make sure no one modifies it.
naturallyVisibleQuery = ->
  published: $ne: false    ## published is false or Date
  deleted: $ne: true
  private: $ne: true

@accessibleMessagesQuery = (group, user = Meteor.user(), client = Meteor.isClient) ->
  ## Mimic logic of `canSee` below.
  canSeeQuery = ->
    if user?.username
      re = atRe user
      $or: [
        naturallyVisibleQuery()
      ,
        "authors.#{escapeUser user.username}": $exists: true
      ,
        title: re
      ,
        body: re
      ]
    else
      naturallyVisibleQuery()
  ## Wild group case effectively unions over all groups
  ## (duplicating logic below when it helps make shorter queries).
  if group == wildGroup
    if canSuper group, client, user #groupRoleCheck group, 'super', user
      ## Global superuser can read all messages (when in superuser mode)
      {}
    else
      groups = memberOfGroups user
      fullGroups = []
      partialGroups = []
      for group in groups
        if groupRoleCheck group, 'read', user
          fullGroups.push group
        else
          partialGroups.push group
      ## Groups with full membership can be combined into one query.
      fullQuery = canSeeQuery()
      fullQuery.group = $in: fullGroups
      if partialGroups.length > 0
        ## Groups with partial membership need their queries OR'd together.
        partialQuery = $or:
          for group in partialGroups
            accessibleMessagesQuery group, user, client
        if fullGroups.length > 0 and partialGroups.length > 0
          $or: [
            fullQuery
            partialQuery
          ]
        else
          partialQuery
      else
        fullQuery  ## also works when fullGroups.length == 0
  else if canSuper group, client, user #groupRoleCheck group, 'super', user
    ## Super-user can see all messages, even unpublished/deleted messages.
    group: group
  else if groupRoleCheck group, 'read', user
    ## Regular users can see all messages they authored, or are @mentioned in,
    ## plus published undeleted messages by others.
    query = canSeeQuery()
    query.group = group
    query
  else if msgs = groupPartialMessagesWithRole group, 'read', user
    $and: [
      group: group
      $or: [
        _id: $in: msgs
      , root: $in: msgs
      ]
      canSeeQuery()
    ]
  else
    null

@messageReaders = (msg, options = {}) ->
  group = findGroup message2group msg
  if options.fields?
    options.fields.roles = true
    options.fields.rolesPartial = true
  users = Meteor.users.find
    username: $in: groupMembers group
  .fetch()
  (user for user in users when canSee msg, false, user, group)

@sortedMessageReaders = (msg, options = {}) ->
  if options.fields?
    options.fields.username = true
    options.fields['profile.fullname'] = true  ## for sorting by fullname
  users = messageReaders msg, options
  _.sortBy users, userSortKey

if Meteor.isServer
  Meteor.publish 'messages.all', (group) ->
    check group, String
    @autorun ->
      query = accessibleMessagesQuery group, findUser @userId
      return @ready() unless query?
      Messages.find query

  Meteor.publish 'messages.imported', (group) ->
    check group, String
    @autorun ->
      query = accessibleMessagesQuery group, findUser @userId
      return @ready() unless query?
      query.imported = $ne: null
      Messages.find query

  Meteor.publish 'messages.root', (group) ->
    check group, String
    @autorun ->
      query = accessibleMessagesQuery group, findUser @userId
      return @ready() unless query?
      query.root = null
      Messages.find query

  Meteor.publish 'messages.submessages', (msgId) ->
    check msgId, String
    @autorun ->
      message = findMessage msgId
      return @ready() unless message?.group?
      query = accessibleMessagesQuery message.group, findUser @userId
      return @ready() unless query?
      root = message.root ? msgId
      Messages.find
        $and: [query,
          $or: [
            _id: root
          , root: root
          ]
        ]

if Meteor.isServer
  ## Returns a query for the messages matching the given query (possibly
  ## with options) along with their roots.  Implicitly we are assuming that,
  ## if a message is accessible, then so is its root.  This is not technically
  ## true if the root is deleted/unpublished and not authored by the user,
  ## in which case we reveal the message to the user (but seems better than
  ## having a dangling root pointer...).
  @addRootsToQuery = (query, options = {}) ->
    #options = _.clone options  ## avoid modifying caller's options
    options.fields = root: 1  ## just get (and depend on) root and _id
    messages = Messages.find query, options
    ids = {}
    messages.forEach (msg) ->
      ids[msg._id] = 1
      ids[msg.root] = 1 if msg.root?
    ids = _.keys ids  ## remove duplicates
    _id: $in: ids

@messagesByQuery = (group, author, atMentions = true) ->
  query =
    group: group
    published: $ne: false
    deleted: $ne: true
    $or: [
      "authors.#{escapeUser author}": $exists: true
    ]
  if group == wildGroup
    delete query.group
  if atMentions
    query.$or.push title: atRe author
    query.$or.push body: atRe author
  query

@messagesBy = (group, author) ->
  Messages.find messagesByQuery(group, author),
    sort: [['updated', 'desc']]
    #limit: parseInt(@limit)

@atMentioned = (message, author) ->
  re = atRe author
  re.test(message.title) or re.test(message.body)

@atMentions = (message) ->
  return [] unless message?
  mentions = []
  re = atRe()
  while (match = re.exec message.title)?
    mentions.push match[1]
  while (match = re.exec message.body)?
    mentions.push match[1]
  mentions

if Meteor.isServer
  Meteor.publish 'messages.author', (group, author) ->
    check group, String
    check author, Match.Optional String  ## defaults to self
    @autorun ->
      me = findUser @userId
      query = accessibleMessagesQuery group, me
      return @ready() unless query?
      unless author?
        return @ready() unless me?
      query = $and: [
        query
        messagesByQuery wildGroup, (author ? me.username)  ## no need to repeat group
      ]
      Messages.find addRootsToQuery query

@messagesTaggedQuery = (group, tag) ->
  query =
    group: group
    "tags.#{escapeTag tag}": $exists: true
    published: $ne: false
    deleted: $ne: true
  if group == wildGroup
    delete query.group
  query

@messagesTagged = (group, tag) ->
  Messages.find messagesTaggedQuery(group, tag),
    sort: [['updated', 'desc']]
    #limit: parseInt(@limit)

if Meteor.isServer
  Meteor.publish 'messages.tag', (group, tag) ->
    check group, String
    check tag, String
    @autorun ->
      query = accessibleMessagesQuery group, findUser @userId
      return @ready() unless query?
      query = $and: [
        query
        messagesTaggedQuery wildGroup, tag  ## no need to repeat group
      ]
      Messages.find addRootsToQuery query

@undeletedMessagesQuery = (group) ->
  query =
    group: group
    published: $ne: false
    deleted: $ne: true
    private: $ne: true
  if group == wildGroup
    delete query.group
  query

@liveMessagesLimit = (limit) ->
  sort: [['updated', 'desc']]
  limit: parseInt limit

if Meteor.isServer
  Meteor.publish 'messages.live', (group, limit) ->
    check group, String
    limit = parseInt limit
    check limit, Number
    @autorun ->
      query = accessibleMessagesQuery group, findUser @userId
      return @ready() unless query?
      ## Mimicking Template.live.helpers' messages
      query = $and: [
        query
        undeletedMessagesQuery wildGroup  ## no need to repeat group
      ]
      options = liveMessagesLimit limit
      Messages.find addRootsToQuery query, options

@parseSince = (since) ->
  try
    match = /^\s*[+-]?\s*([\d.]+)\s*(\w+)\s*$/.exec since
    if match?
      amount = parseFloat match[1]
      return null if isNaN amount
      moment().subtract(amount, match[2]).toDate()
    else
      match = /^\s*(\d+)\s*:\s*(\d+)\s*$/.exec since
      if match?
        d = moment().hour(match[1]).minute(match[2])
        if moment().diff(d) < 0
          d = d.subtract(1, 'day')
        d.toDate()
      else
        d = moment(since)
        return null unless d.isValid()
        d.toDate()
  catch
    null

if Meteor.isServer
  Meteor.publish 'messages.since', (group, since) ->
    check group, String
    check since, String
    @autorun ->
      query = accessibleMessagesQuery group, findUser @userId
      return @ready() unless query?
      pSince = parseSince since
      return @ready() unless pSince?
      ## Mimicking since.coffee's messagesSince
      query.updated = $gte: pSince
      Messages.find addRootsToQuery query

if Meteor.isServer
  Meteor.publish 'messages.diff', (message) ->
    check message, String
    @autorun ->
      if canSee message, false, findUser @userId
        MessagesDiff.find
          id: message
      else
        @ready()

#if Meteor.isServer
#  Meteor.publish 'messages.summary', (group) ->
#    check group, String
#    roots = {}
#    @autorun =>
#      if groupRoleCheck group, 'read', findUser @userId
#        rootMessages(group).forEach (root) =>
#          summary =
#            count: _submessageCount root
#            updated: _submessageLastUpdate root
#          id = root._id
#          if id of roots
#            @changed 'messages.summary', id, summary
#          else
#            summary.root = id
#            @added 'messages.summary', id, summary
#            roots[id] = true
#    @ready()
#
#if Meteor.isClient
#  @MessagesSummary = new Mongo.Collection 'messages.summary'
#
#  @messageSummary = (root) ->
#    root = root._id if root._id?
#    MessagesSummary.findOne root

if Meteor.isServer
  ## Remove all editors on server start, so that we can restart listeners.
  Messages.find().forEach (message) ->
    if message.editing?.length
      Messages.update message._id,
        $unset: editing: ''

  onExit ->
    console.log 'EXITING'

@canSee = (message, client = Meteor.isClient, user = Meteor.user(), group) ->
  ## Visibility of a message is implied by its existence in the Meteor.publish
  ## above, so we don't need to check this in the client.  But this function
  ## is still needed in the server for messages.diff subscription above,
  ## and when simulating non-superuser mode in client/message.coffee.
  message = findMessage message
  return false unless message?
  group = findGroup message.group unless group?
  if canSuper group, client, user #groupRoleCheck group, 'super', user
    ## Super-user can see all messages, even unpublished/deleted messages.
    true
  else if messageRoleCheck group, message, 'read', user
    ## Regular users can see all messages they authored, plus
    ## published undeleted public messages by others.
    (message.published and not message.deleted and not message.private) or
    amAuthor message, user
  else
    false

@canPost = (group, parent, user = Meteor.user()) ->
  #Meteor.userId()? and
  user? and
  messageRoleCheck group, parent, 'post', user

@canEdit = (message, user = Meteor.user()) ->
  ## Can edit message if an "author" (e.g. the creator or edited in the past),
  ## or if we have global edit privileges in this group or thread.
  message = findMessage message
  return false unless message?
  user? and (
    amAuthor(message, user) or
    messageRoleCheck message.group, message, 'edit', user
  )

@canDelete = canEdit
@canUndelete = canEdit
@canPublish = canEdit
@canUnpublish = canEdit
@canMinimize = canEdit
@canUnminimize = canEdit
## Older behavior: only superusers can unpublish once published
#@canUnpublish = (message) ->
#  canSuper message2group message

@canSuper = (group, client = Meteor.isClient, user = Meteor.user()) ->
  ## If client is true, we use the session variable 'super' to fake whether
  ## superuser mode is viewed as on (from the client perspective).
  ## This lets someone with superuser permissions pretend to be normal.
  (not client or Session.get 'super') and
  groupRoleCheck group, 'super', user

@canImport = (group) -> canSuper group
@canSuperdelete = (message) ->
  canSuper message2group message

@amAuthor = (message, user = Meteor.user()) ->
  message = findMessage message
  return false unless user?.username
  escapeUser(user.username) of (message.authors ? {}) or
  (message.title and atRe(user).test message.title) or
  (message.body and atRe(user).test message.body)

@canPrivate = (message) ->
  message = findMessage message
  if canSuper message.group
    ## Superuser can always change private flag
    true
  else
    ## Regular user can change private flag for their own messages,
    ## and only if thread privacy allows for both public and private.
    unless amAuthor message
      false
    else
      root = findMessageRoot message
      root.threadPrivacy? and 'public' in root.threadPrivacy and 'private' in root.threadPrivacy

@canAdmin = (group, message = null) ->
  messageRoleCheck group, message, 'admin'

idle = 1000   ## one second

@message2group = (message) ->
  findMessage(message)?.group
@message2root = (message) ->
  findMessage(message)?.root ? message?._id ? message

@findMessage = (message, options) ->
  if message? and not message._id?
    message = Messages.findOne message, options
  message

@findMessageParent = (message) ->
  message = message._id if message._id?
  parents = Messages.find
    children: message
  .fetch()
  switch parents.length
    when 0
      null
    when 1
      parents[0]
    else
      throw new Meteor.Error 'findMessageParent.multiple',
        "Message #{message} has #{parents.length} parents! #{parents}"

@findMessageRoot = (message) ->
  return message unless message?
  message = findMessage message
  if message.root?
    Messages.findOne message.root
  else
    message

@messageEmpty = (message) ->
  message = findMessage message
  message.title.trim().length == 0 and
  message.body.trim().length == 0 and
  not message.file

_noLongerRoot = (message) ->
  Messages.update message,
    $unset:
      submessageCount: ''
      submessageLastUpdate: ''

#_submessageCount = (root) ->
#  root = root._id if root._id?
#  Messages.find
#    root: root
#    published: $ne: false    ## published is false or Date
#    deleted: $ne: true
#    private: $ne: true
#  .count()
#
#_submessageLastUpdate = (root) ->
#  root = findMessage root
#  return null unless root?
#  updated = root.updated
#  Messages.find
#    root: root._id
#    published: $ne: false    ## published is false or Date
#    deleted: $ne: true
#    private: $ne: true
#  ,
#    fields:
#      updated: true
#  .forEach (submessage) ->
#    updated = dateMax updated, submessage.updated
#  updated

_consideredSubmessage = (msg1, msg2 = {}) ->
  (msg1.published ? msg2.published) != false and
  (msg1.deleted ? msg2.deleted) != true and
  (msg1.private ? msg2.private) != true

_submessagesChanged = (root) ->
  return unless root?
  root = findMessage root
  return null unless root?
  count = 0
  updated = root.updated
  query = Messages.find
    root: root._id
    ## Mimicking _consideredSubmessage above
    published: $ne: false    ## published is false or Date
    deleted: $ne: true
    private: $ne: true
  ,
    fields:
      updated: true
  query.forEach (submessage) ->
    count += 1
    updated = dateMax updated, submessage.updated
  ## When Meteor.Collection supports aggregate...
  #Messages.aggregate [
  #  $match:
  #    root: root._id
  #    published: $ne: false    ## published is false or Date
  #    deleted: $ne: true
  #    private: $ne: true
  #,
  #  $group:
  #    _id: null          ## aggregate all matches into one document
  #    submessageCount: $sum: 1
  #    submessageLastUpdate: $max: 'updated'
  #].fetch()[0]
  Messages.update root,
    $set:
      submessageCount: count #_submessageCount root
      submessageLastUpdate: updated #_submessageLastUpdate root

if Meteor.isServer
  rootMessages().forEach _submessagesChanged

checkPrivacy = (privacy, root, user = Meteor.user()) ->
  return unless privacy?
  root = findMessageRoot root  ## can pass message or message ID
  return unless root?
  unless canSuper root.group, false, user
    switch privacy
      when true
        unless root.threadPrivacy? and 'private' in root.threadPrivacy
          throw new Meteor.Error 'checkPrivacy.privateForbidden',
            "Cannot make message private in thread '#{root._id}'"
      when false
        unless root.threadPrivacy? and 'public' in root.threadPrivacy
          throw new Meteor.Error 'checkPrivacy.publicForbidden',
            "Cannot make message public in thread '#{root._id}'"
  null

export messageContentFields = [
  'title'
  'body'
  'format'
  'file'
  'tags'
  'published'
  'deleted'
  'private'
  'minimized'
  'rotate'
]

export messageExtraFields = [
  'editing'
  'submessageCount'
  'submessageLastUpdated'
  #'children'
  #'root'
]

export messageFilterExtraFields = (msg) ->
  if msg?  ## important to preserve null, to represent "no old" (created)
    _.omit msg, messageExtraFields
  else
    msg

## The following should be called directly only on the server;
## clients should use the corresponding method.
_messageUpdate = (id, message, authors = null, old = null) ->
  ## Compare with 'old' if provided (in cases when it's already been
  ## fetched by the server); otherwise, load id from Messages.
  old = Messages.findOne id unless old?

  ## authors is set only when internal to server, in which case we bypass
  ## authorization checks, which already happened in messageEditStart.
  unless authors?
    ## If authors == null, we're guaranteed to be in a method, so we
    ## can use Meteor.user().
    user = Meteor.user()
    #check Meteor.userId(), String  ## should be done by 'canEdit'
    authors = [user.username]
    unless canEdit old, user
      throw new Meteor.Error 'messageUpdate.unauthorized',
        "Insufficient permissions to edit message '#{id}' in group '#{old.group}'"
    checkPrivacy message.private, old, user
  check message,
    #url: Match.Optional String
    title: Match.Optional String
    body: Match.Optional String
    format: Match.Optional String
    file: Match.Optional String
    tags: Match.Optional Match.Where validTags
    #children: Match.Optional [String]  ## must be set via messageParent
    #parent: Match.Optional String      ## use children, not parent
    published: Match.Optional Boolean
    deleted: Match.Optional Boolean
    private: Match.Optional Boolean
    minimized: Match.Optional Boolean
    rotate: Match.Optional Match.Where (r) ->
      typeof r == "number" and -180 < r <= 180

  ## Don't update if there aren't any actual differences.
  difference = false
  for own key of message
    if old[key] != message[key]
      difference = true
      break
  return unless difference

  now = new Date
  if message.published == true
    message.published = now
  message.updated = now
  message.updators = authors
  diff = _.clone message
  for author in authors
    message["authors.#{escapeUser author}"] = now
  Messages.update id,
    $set: message
  diff.id = id
  diffid = MessagesDiff.insert diff
  diff._id = diffid
  #_submessagesChanged old.root ? id
  ## In this special case, we can efficiently simulate the behavior of
  ## _submessagesChanged via a direct update to the root:
  if Meteor.isServer and (not old.root? or _consideredSubmessage message, old)
    rootUpdate = $max: submessageLastUpdate: message.updated
    if old.root? and not _consideredSubmessage old
      rootUpdate.$inc = submessageCount: 1  ## considered a new submessage
    Messages.update (old.root ? id), rootUpdate
  else if _consideredSubmessage old
    ## If this message is no longer considered a submessage, we need to
    ## recompute from scratch in order to find the new last update.
    _submessagesChanged old.root ? id
  notifyMessageUpdate message, old if Meteor.isServer  ## client in simulation
  diffid

_messageAddChild = (child, parent, position = null) ->
  if position?
    Messages.update parent,
      $push: children:
        $each: [child]
        $position: position
  else
    Messages.update parent,
      $push: children: child

_messageParent = (child, parent, position = null, oldParent = true, importing = false) ->
  ## oldParent is an internal option for server only; true means "search for/
  ## deal with old parent", while null means we assert there is no old parent.

  cmsg = Messages.findOne child
  unless cmsg?
    throw new Meteor.Error 'messageParent.noChild',
      "Missing child message #{child} to reparent"
  if parent?
    ## On server, can give a parent message instead of an ID, to save query.
    if parent._id?
      pmsg = parent
      parent = pmsg._id
    else
      pmsg = Messages.findOne parent
      unless pmsg?
        ## This can happen in client simulation when parent isn't in
        ## subscription.
        return if Meteor.isClient
        throw new Meteor.Error 'messageParent.noParent',
          "Missing parent message #{parent} to reparent"
    group = pmsg.group
    root = pmsg.root ? parent
  else
    group = cmsg.group  ## xxx can't reparent into root message of other group
    root = null

  unless canEdit(child) and canPost group, parent
    throw new Meteor.Error 'messageParent.unauthorized',
      "Insufficient privileges to reparent message #{child} into #{parent}"

  ## Check before creating a cycle in the parent pointers.
  ## This can happen only if we are making the message nonroot (parent
  ## nonnull) and the child has children of its own.
  if parent? and cmsg.children?.length
    for ancestor from ancestorMessages pmsg, true
      if ancestor._id == child
        throw new Meteor.Error 'messageParent.cycle',
          "Attempt to make #{child} its own ancestor (via #{parent})"

  oldPosition = null
  oldSiblingsBefore = null
  oldSiblingsAfter = null
  if oldParent
    oldParentMsg = findMessageParent child
    if oldParentMsg?
      oldParent = oldParentMsg._id
      oldPosition = oldParentMsg.children.indexOf child
      return if parent == oldParent and (
        (position? and position == oldPosition) or
        (not position? and oldPosition == oldParentMsg.children.length-1)
      )  ## no-op
      oldSiblingsBefore = oldParentMsg.children[...oldPosition]
      oldSiblingsAfter = oldParentMsg.children[oldPosition+1..]
      Messages.update oldParent,
        $pull: children: child
    else
      oldParent = null
  return if parent == oldParent == null  ## no-op, root case
  if parent?
    _messageAddChild child, parent, position
  if root != cmsg.root
    update = root: root
    if group != cmsg.group
      update.group = group
      ## First MessagesDiff has the initial group; add Diff if it changes.
      ## (Unclear whether we should track group at all, though.)
      now = new Date
      username = Meteor.user().username
      MessagesDiff.insert
        id: cmsg._id
        group: cmsg.group
        updated: now
        updators: [username]
      Messages.update child,
        $set: _.extend {"authors.#{escapeUser username}": now}, update
    else
      Messages.update child,
        $set: update
    EmojiMessages.update
      message: child
    ,
      $set: update
    ,
      multi: true
    if cmsg.root?
      ## If we move a nonroot message to have new root, update descendants.
      descendants = descendantMessageIds cmsg
      if descendants.length > 0
        Messages.update
          _id: $in: descendants
        ,
          $set: root: root ? child
        ,
          multi: true
        EmojiMessages.update
          message: $in: descendants
        ,
          $set: root: root ? child
        ,
          multi: true
    else if cmsg.children?.length
      ## To reparent root message (with children),
      ## change the root of all descendants.
      Messages.update
        root: child
      ,
        $set: update  # root: root ? child  ## actually must be root
      ,
        multi: true
      EmojiMessages.update
        root: child
      ,
        $set: update  # root: root ? child  ## actually must be root
      ,
        multi: true
      _noLongerRoot child if root?
    _submessagesChanged cmsg.root     ## old root
    _submessagesChanged root ? child  ## new root

  doc =
    child: child
    parent: parent
    position: position
    oldParent: oldParent
    oldPosition: oldPosition
    oldSiblingsBefore: oldSiblingsBefore
    oldSiblingsAfter: oldSiblingsAfter
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

  ## If we're using a persistent store for sharejs, we need to cleanup
  ## leftover documents from last time.  This should only be for local
  ## testing, but deleting them at startup prevents more catastrophic
  ## failure when creating a duplicate ID.
  docs = new Mongo.Collection 'docs'
  docs.find().forEach (doc) ->
    ShareJS.model.delete doc._id

  editor2messageUpdate = (id, editors) ->
    Meteor.clearTimeout editorTimers[id]
    doc = Meteor.wrapAsync(ShareJS.model.getSnapshot) id
    #console.log id, 'changed to', doc.snapshot
    msg = findMessage id
    unless msg.body == doc.snapshot
      _messageUpdate id,
        body: doc.snapshot
      , editors, msg

  delayedEditor2messageUpdate = (id) ->
    Meteor.clearTimeout editorTimers[id]
    editors = findMessage(id).editing
    editorTimers[id] = Meteor.setTimeout ->
      editor2messageUpdate id, editors
    , idle

Meteor.methods
  messageUpdate: (id, message) -> _messageUpdate id, message

  messageNew: (group, parent = null, position = null, message = {}) ->
    #check Meteor.userId(), String  ## should be done by 'canPost'
    check parent, Match.OneOf String, null
    check position, Match.Maybe Number
    check group, String
    check message,
      title: Match.Optional String
      body: Match.Optional String
      format: Match.Optional String
      file: Match.Optional String
      tags: Match.Optional Match.Where validTags
      #children: Match.Optional [String]  ## must be set via messageParent
      #parent: Match.Optional String      ## use children, not parent
      published: Match.Optional Boolean
      deleted: Match.Optional Boolean
      private: Match.Optional Boolean
      minimized: Match.Optional Boolean
      rotate: Match.Optional Match.Where (r) ->
        typeof r == "number" and -180 < r <= 180
    user = Meteor.user()
    unless canPost group, parent, user
      throw new Meteor.Error 'messageNew.unauthorized',
        "Insufficient permissions to post new message in group '#{group}' under parent '#{parent}'"
    root = findMessageRoot parent
    checkPrivacy message.private, root, user
    unless message.private?
      ## If root says private only, default is to be private.
      ## Otherwise, match parent.
      if root?.threadPrivacy? and 'public' not in root.threadPrivacy
        message.private = true
      else if parent?
        pmsg = Messages.findOne parent
        message.private = pmsg.private if pmsg.private?
      ## Old default: public if available, private otherwise
      #if root?.threadPrivacy? and 'public' not in root.threadPrivacy
      #  message.private = true
    now = new Date
    message.group = group
    ## Default content.
    message.title = "" unless message.title?
    message.body = "" unless message.body?
    message.format = user?.profile?.format or defaultFormat unless message.format?
    message.tags = {} unless message.tags?
    message.published = autopublish user unless message.published?
    message.updators = [user.username]
    message.updated = now
    if message.published == true
      message.published = now
    message.deleted = false unless message.deleted?
    ## Content specific to Messages, not MessagesDiff
    diff = _.clone message
    message.creator = user.username
    message.created = now
    message.authors =
      "#{escapeUser user.username}": now
    #message.parent: parent         ## use children, not parent
    message.children = []
    ## Speed up _messageParent by presetting root
    if parent?
      message.root = root._id
    else
      message.root = null
      message.submessageCount = 0
      message.submessageLastUpdate = now
    ## Actual insertion
    id = Messages.insert message
    message._id = id
    ## Parenting
    if parent?
      #_messageParent id, parent, position, null  ## there's no old parent
      _messageAddChild id, parent, position
      ## Because we preset root, even _messageParent won't call
      ## _submessagesChanged for us.
      ## (We already simulated the effect when message is its own root.)
      #_submessagesChanged message.root
      ## In fact, in this special case, we can efficiently simulate the
      ## behavior of _submessagesChanged via a direct update to the root:
      if Meteor.isServer and _consideredSubmessage message
        Messages.update message.root,
          $inc: submessageCount: 1
          $max: submessageLastUpdate: message.updated
    ## Store diff
    diff.id = id
    diffid = MessagesDiff.insert diff
    diff._id = diffid
    notifyMessageUpdate message, null if Meteor.isServer  ## null means created
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
    check Meteor.userId(), String  ## should be done by 'canEdit'
    check parent, Match.OneOf String, null
    check position, Match.Maybe Number
    _messageParent child, parent, position

  messageEditStart: (id) ->
    #check Meteor.userId(), String  ## should be done by 'canEdit'
    unless canEdit id
      throw new Meteor.Error 'messageEditStart.unauthorized',
        "Insufficient permissions to edit message '#{id}'"
    if Meteor.isServer
      old = Messages.findOne id
      return unless old?
      unless old.editing?.length
        ShareJS.model.delete id
        ShareJS.initializeDoc id, old.body ? ''
        timer = null
        listener = Meteor.bindEnvironment (opData) ->
          delayedEditor2messageUpdate id
        ShareJS.model.listen id, listener
      ## We used to do the following update in client too, to do
      ## speculatively, but it seems problematic for now.
      Messages.update id,
        $addToSet: editing: Meteor.user().username

  messageEditStop: (id) ->
    check Meteor.userId(), String
    if Meteor.isServer
      ## We used to do the following update in client too, to do
      ## speculatively, but it seems problematic for now.
      Messages.update id,
        $pull: editing: Meteor.user().username
      unless Messages.findOne(id).editing?.length
        editor2messageUpdate id, [Meteor.user().username]
        ShareJS.model.delete id
    ## xxx should add to last MessagesDiff (possibly just made) that
    ## Meteor.user().username just committed this version.

  messageImport: (group, parent, message, diffs) ->
    #check Meteor.userId(), String  ## should be done by 'canImport'
    check group, String
    check parent, Match.OneOf String, null
    check message,
      title: Match.Optional String
      body: Match.Optional String
      format: Match.Optional String
      file: Match.Optional String
      tags: Match.Optional Match.Where validTags
      #children: Match.Optional [String]  ## must be set via messageParent
      #parent: Match.Optional String      ## use children, not parent
      published: Match.Optional Match.OneOf Date, Boolean
      deleted: Match.Optional Boolean
      #private: Match.Optional Boolean
      #minimized: Match.Optional Boolean
      creator: Match.Optional String
      created: Match.Optional Date
      #updated and updators added automatically from last diff
    ## Default content.
    message.title = "" unless message.title?
    message.body = "" unless message.body?
    message.format = Meteor.user()?.profile?.format or defaultFormat unless message.format?
    message.tags = {} unless message.tags?
    check diffs, [
      title: Match.Optional String
      body: Match.Optional String
      format: Match.Optional String
      file: Match.Optional String
      tags: Match.Optional Match.Where validTags
      deleted: Match.Optional Boolean
      #private: Match.Optional Boolean
      #minimized: Match.Optional Boolean
      updated: Match.Optional Date
      updators: Match.Optional [String]
      published: Match.Optional Match.OneOf Date, Boolean
    ]
    unless canImport group
      throw new Meteor.Error 'messageImport.unauthorized',
        "Insufficient permissions to import into group '#{group}'"
    now = new Date
    me = Meteor.user().username
    if message.published == true
      message.published = now
    message.deleted = false unless message.deleted?
    diffs[0].deleted = false unless diffs[0].deleted?
    message.group = group
    message.children = []
    message.updated = diffs[diffs.length-1].updated
    message.updators = diffs[diffs.length-1].updaors
    message.importer = me
    message.imported = now
    ## Automatically set 'authors' to have the latest update for each author.
    message.authors = {}
    for diff in diffs
      for author in diff.updators
        message.authors[author] = diff.updated
    #if parent?
    #  pmsg = Messages.findOne parent
    #  message.root = pmsg.root ? parent
    id = Messages.insert message
    for diff in diffs
      diff.id = id
      diff.group = group
      diff.importer = me
      diff.imported = now
      MessagesDiff.insert diff
    if parent?
      _messageParent id, parent, null, null, true
    else
      _submessagesChanged message
    id

  messageSuperdelete: (message) ->
    #check Meteor.userId(), String  ## should be done by 'canSuperdelete'
    check message, String
    unless canSuperdelete message
      throw new Meteor.Error 'messageSuperdelete.unauthorized',
        "Insufficient permissions to superdelete in group '#{group}'"
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
      ## children roots remain the same in this case
      _submessagesChanged msg.root
      for child, i in children
        MessagesParent.insert
          child: child
          position: i + parent.children.indexOf message
          parent: parent
          updator: user
          updated: now
    else
      #_submessagesChanged message  ## unnecessary now that it's deleted
      for child in children
        Messages.update child,
          $unset: root: ''
        _submessagesChanged child
        descendants = descendantMessageIds child
        if descendants.length > 0
          Messages.update
            _id: $in: descendants
          ,
            $set: root: child
          ,
            multi: true
          EmojiMessages.update
            message: $in: descendants
          ,
            $set: root: child
          ,
            multi: true
    
    ## Delete all associated files.
    MessagesDiff.find
      id: message
    .forEach (diff) ->
      if diff.file
        deleteFile diff.file
    ## Delete all diffs for this message.
    MessagesDiff.remove
      id: message
    ## Delete all parent references to this message.
    MessagesParent.remove
      $or: [
        child: message
      , parent: message
      ]
    ## Delete all emoji responses to this message.
    EmojiMessages.remove
      message: message

  threadPrivacy: (message, list) ->
    #check Meteor.userId(), String  ## should be done by 'canSuper'
    check message, String
    check list, [Match.OneOf 'public', 'private']
    list = _.uniq list  ## remove any duplicates
    unless canSuper message2group message
      throw new Meteor.Error 'threadPrivacy.unauthorized',
        "Insufficient permissions to change privacy for thread '#{message}'"
    msg = Messages.findOne message
    if msg.root?
      throw new Meteor.Error 'threadPrivacy.nonroot',
        "Can change thread privacy only for root messages, not '#{message}'"
    Messages.update message,
      $set: threadPrivacy: list

  recomputeAuthors: ->
    ## Force recomputation of all `authors` fields to be the latest update
    ## for each updator.
    #check Meteor.userId(), String  ## should be done by 'canSuper'
    unless canSuper wildGroup
      throw new Meteor.Error 'recomputeAuthors.unauthorized',
        "Insufficient permissions to recompute authors in group '#{wildGroup}'"
    Messages.find({}).forEach (msg) ->
      authors = {}
      updated = updators = null
      MessagesDiff.find
        id: msg._id
      .forEach (diff) ->
        updated = diff.updated
        updators = diff.updators
        for updator in updators
          escape = escapeUser updator
          if escape not of authors or authors[escape].getTime() < updated.getTime()
            authors[escape] = updated
      Messages.update msg._id,
        $set:
          authors: authors
          updated: updated    ## last one
          updators: updators  ## last one

  recomputeRoots: ->
    #check Meteor.userId(), String  ## should be done by 'canSuper'
    unless canSuper wildGroup
      throw new Meteor.Error 'recomputeRoots.unauthorized',
        "Insufficient permissions to recompute roots in group '#{wildGroup}'"
    rootMessages().forEach (root) ->
      EmojiMessages.update
        message: root._id
      ,
        $set: root: null
      ,
        multi: true
      descendants = descendantMessageIds root
      if descendants.length > 0
        Messages.update
          _id: $in: descendants
        ,
          $set: root: root._id
        ,
          multi: true
        EmojiMessages.update
          message: $in: descendants
        ,
          $set: root: root._id
        ,
          multi: true

## On client, requires messages.root subscription
@messageNeighbors = (root) ->
  return unless root._id?
  messages = groupSortedBy root.group, groupDefaultSort(root.group),
    fields:
      title: 1
      group: 1
  messages = messages.fetch() if messages.fetch?
  ids = (message._id for message in messages)
  index = ids.indexOf root._id
  return unless index >= 0
  neighbors = {}
  neighbors.prev = messages[index-1] if index > 0
  neighbors.next = messages[index+1] if index < messages.length - 1
  neighbors
