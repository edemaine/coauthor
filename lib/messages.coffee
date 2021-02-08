import { defaultFormat } from './settings.coffee'
import { ShareJS } from 'meteor/edemaine:sharejs'

idleUpdate = 1000      ## one second of idle time before edits update message
export idleStop = 60*60*1000  ## one hour of idle time before auto stop editing

## Thanks to https://github.com/aldeed/meteor-simple-schema/blob/4ead24bcc92e9963dd994c07d275eac144733c3e/simple-schema.js#L548-L551
@idRegex = "[23456789ABCDEFGHJKLMNPQRSTWXYZabcdefghijkmnopqrstuvwxyz]{17}"

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
  ## Diffs are accessed by message ID, and then sorted by updated date.
  MessagesDiff._ensureIndex [
    ['id', 1]
    ['updated', 1]
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
  start = message._id ? message
  if self and message?
    yield findMessage message
  loop
    message = findMessageParent message
    break unless message?
    if message._id == start
      throw new Meteor.Error 'ancestorMessages.cycle',
        "There is already a cycle in ancestors of #{start}!"
    yield message

## These queries mimic the logic of `canSee` below; keep them synchronized!

naturallyVisibleQuery = ->
  ## Users with read permission can see all published undeleted public messages.
  ## Recompute this query every time to make sure no one modifies them.
  ## Query guaranteed to not include `group` or `$or` qualifiers.
  published: $ne: false    ## published is false or Date
  deleted: $ne: true
  private: $ne: true
explicitAccessQuery = (user) ->
  ## In any group, a logged-in user can see messages they coauthored,
  ## independent of status, and any undeleted published (presumably private)
  ## message with explicit access.
  ## Guaranteed to be a sole $or query.
  return null unless user?.username
  $or: [
    coauthors: user.username
  ,
    access: user.username
    published: $ne: false    ## published is false or Date
    deleted: $ne: true
  ]
readableCanSeeQuery = (user) ->
  ## Users with read permission can see the union of above two queries.
  if query = explicitAccessQuery user
    # ASSERT: query consists solely of an $or node
    query.$or.unshift naturallyVisibleQuery()
    query
  else
    naturallyVisibleQuery()

@accessibleMessagesQuery = (group, user = Meteor.user(), client = Meteor.isClient) ->
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
      if fullGroups.length > 0
        ## Use naturallyVisibleQuery instead of readableCanSeeQuery
        ## because we $or on explicitAccessQuery once later.
        fullQuery = naturallyVisibleQuery()
        fullQuery.group = $in: fullGroups
      ## Groups with partial membership need their queries $or'd together.
      if partialGroups.length > 0
        partialQuery = $or:
          for group in partialGroups
            ## Simulate `accessibleMessagesQuery group, user, client`
            ## but without $or'ing in explicitAccessQuery (done once later).
            msgs = groupPartialMessagesWithRole group, 'read', user
            query = naturallyVisibleQuery()
            query.group = group
            query.$or = [
              _id: $in: msgs
            ,
              root: $in: msgs
            ]
            query
      ## Combine above queries with explicitAccessQuery.
      explicitQuery = explicitAccessQuery user
      if explicitQuery? or fullQuery? or partialQuery?
        $or: [
          fullQuery
          partialQuery
          explicitQuery
        ].filter (x) -> x?  # omit undefined/null queries
      else
        null
  else if canSuper group, client, user #groupRoleCheck group, 'super', user
    ## Super-user can see all messages, even unpublished/deleted messages.
    group: group
  else if groupRoleCheck group, 'read', user
    ## Regular users (with read access) can see all messages they coauthored,
    ## all (private) published undeleted messages they have explicit access to,
    ## and all public published undeleted messages in the group.
    query = readableCanSeeQuery user
    # ASSERT: query does not already have group qualifier.
    query.group = group
    query
  else if (msgs = groupPartialMessagesWithRole group, 'read', user).length
    ## Partial users can see all messages they coauthored,
    ## all published undeleted messages they have explicit access to, plus
    ## public published undeleted messages among the threads they can read.
    query = naturallyVisibleQuery()
    # ASSERT: query does not already have $or qualifier.
    query.$or = [
      _id: $in: msgs
    ,
      root: $in: msgs
    ]
    group: group
    $or: [
      query
    ,
      explicitAccessQuery user
    ].filter (x) -> x?  # in case explicitAccessQuery returns null
  else
    ## Without read access (a weird permission scenario, e.g. write-only),
    ## we still let the user gain access to messages they coauthored and
    ## published undeleted messages with explicit access.
    query = explicitAccessQuery user
    query.group = group if query?
    query

## Analog of `messageSubscribers`, but listing everyone who might potentially
## be subscribed.
@messageReaders = (msg, options = {}) ->
  msg = findMessage msg
  return [] unless msg?
  group = findGroup msg.group
  if options.fields?
    options.fields.roles = true
    options.fields.rolesPartial = true
  users = Meteor.users.find
    username: $in: groupMembers group
  .fetch()
  for user in users
    continue unless canSee msg, false, user, group
    continue unless fullMemberOfGroup(group, user) or memberOfThread(msg, user)
    user

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
  ## with options) along with their roots.  The query gets $and'ed together
  ## with the specified `accessibleQuery` to guarantee that any matched
  ## messages and roots are accessible to the user.
  @addRootsToQuery = (accessibleQuery, query, options) ->
    if options?
      options = _.clone options  ## avoid modifying caller's options
    else
      options = {}
    options.fields = root: 1  ## just get (and depend on) root and _id
    messages = Messages.find $and: [
      query
      accessibleQuery  # add this here too in case it vastly shrinks results
    ], options
    ids = {}
    messages.forEach (msg) ->
      ids[msg._id] = 1
      ids[msg.root] = 1 if msg.root?
    ids = _.keys ids  ## remove duplicates
    $and: [
      _id: $in: ids
      accessibleQuery
    ]

  ## Call `addRootsToQuery` if we're in the global group; otherwise, just $and
  ## the `query` and `accessibleQuery` together (as the `messages.root`
  ## subscription should cover all the roots we need).
  ## Modifies provides options for the new query.
  @maybeAddRootsToQuery = (group, accessibleQuery, query, options) ->
    if group == wildGroup
      newQuery = addRootsToQuery accessibleQuery, query, options
      delete options?.limit  # don't limit query that has roots added
      newQuery
    else
      $and: [
        query
        accessibleQuery
      ]

## Query for all published undeleted (public and private) messages
## in a specified group coauthored by the specified author.
## Also, unless `atMentions = false`, add messages that @mention the author.
@messagesByQuery = (group, author, atMentions = true) ->
  query =
    group: group
    published: $ne: false
    deleted: $ne: true
    $or: [
      coauthors: author
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

@atMentions = (message, usernames) ->
  return [] unless message?
  mentions = []
  re = atRe usernames

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
      accessibleQuery = accessibleMessagesQuery group, me
      return @ready() unless accessibleQuery?
      return @ready() unless author? or me?
      byQuery = messagesByQuery group, (author ? me.username)
      Messages.find maybeAddRootsToQuery group, accessibleQuery, byQuery

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

###
if Meteor.isServer
  Meteor.publish 'messages.tag', (group, tag) ->
    check group, String
    check tag, String
    @autorun ->
      accessibleQuery = accessibleMessagesQuery group, findUser @userId
      return @ready() unless accessibleQuery?
      tagQuery = messagesTaggedQuery group, tag
      Messages.find maybeAddRootsToQuery group, accessibleQuery, tagQuery
###

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
      accessibleQuery = accessibleMessagesQuery group, findUser @userId
      return @ready() unless accessibleQuery?
      ## Mimicking Template.live.helpers' messages
      liveQuery = undeletedMessagesQuery group
      options = liveMessagesLimit limit
      query = maybeAddRootsToQuery group, accessibleQuery, liveQuery, options
      Messages.find query#, options

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
      accessibleQuery = accessibleMessagesQuery group, findUser @userId
      return @ready() unless accessibleQuery?
      pSince = parseSince since
      return @ready() unless pSince?
      ## Mimicking since.coffee's messagesSince
      sinceQuery =
        group: group
        updated: $gte: pSince
      Messages.find maybeAddRootsToQuery group, accessibleQuery, sinceQuery

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
  else if haveExplicitAccess message, user
    ## Regular users can see all messages they have explicit access to:
    ## either coauthored or are in the 'access' list (and in the latter case,
    ## the message is published and not deleted but potentially private).
    true
  else if messageRoleCheck group, message, 'read', user
    ## Users with read permission (possibly just for the thread)
    ## can see all published undeleted public messages.
    ## (See also `naturallyVisibleQuery` above which mimics this test.)
    message.published and not message.deleted and not message.private
  else
    false

@canPost = (group, parent, user = Meteor.user()) ->
  #Meteor.userId()? and
  user? and
  messageRoleCheck group, parent, 'post', user

@canReply = (message) ->
  canPost message.group, message._id

@canEdit = (message, client = Meteor.isClient, user = Meteor.user()) ->
  ## Can edit message if a coauthor (explicit read/write access);
  ## or if we have global edit privileges in this group or thread,
  ## in addition to being able to see the message itself
  ## (a slight variation to the logic of `canSee` which needs `read` access);
  ## or a superuser.
  message = findMessage message
  return false unless message?
  user? and (
    canSuper(message.group, client, user) or
    amCoauthor(message, user) or
    (messageRoleCheck(message.group, message, 'edit', user) and
     ((message.published and not message.deleted and not message.private) or
      haveExplicitAccess(message, user))))

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

## A user has explicit [read] access to a message if they are a coauthor or
## they are listed in the 'access' list and the message is published and
## not deleted (but possibly private).
@haveExplicitAccess = (message, user = Meteor.user()) ->
  return false unless user?.username
  message = findMessage message
  return false unless message?
  (user.username in message.coauthors) or
  (message.access? and (user.username in message.access) and
   message.published and not message.deleted)
## A user has explicit read/write access to a message if they are a coauthor.
@amCoauthor = (message, user = Meteor.user()) ->
  return false unless user?.username
  message = findMessage message
  return false unless message?
  user.username in message.coauthors

@canPrivate = (message) ->
  message = findMessage message
  return false unless message?.group?
  if canSuper message.group
    ## Superuser can always change private flag
    true
  else
    ## Regular user can change private flag for their coauthored messages,
    ## and only if thread privacy allows for both public and private,
    ## and not for the root message of the thread.
    unless amCoauthor message
      false
    else
      root = findMessageRoot message
      root? and
      root._id != message._id and
      root.threadPrivacy? and
      'public' in root.threadPrivacy and
      'private' in root.threadPrivacy

@canAdmin = (group, message = null) ->
  messageRoleCheck group, message, 'admin'

@canMaybeParent = canEdit  # could this message may be reparented?
@canParent = (child, parent, group) ->  # is this parent operation allowed?
  child = findMessage child
  parent = findMessage parent
  group ?= parent.group
  ## Need target group, either from parent or argument (to make root message)
  return false unless group?
  ## Moving a message across groups will cause users in current group to lose
  ## access to the message; require superuser access in that group.
  if child.group != group
    return false unless canSuper child.group
  ## Need to be able to edit the child message and be able to post within
  ## the target parent.
  canEdit(child) and canPost group, parent

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

@findLastDiff = (id) ->
  MessagesDiff.find
    id: id
  ,
    sort: [['updated', 'desc']]
    limit: 1
  .fetch()?[0]

@finishLastDiff = (id, editing) ->
  lastDiff = findLastDiff id
  return unless lastDiff?
  relevant = (editor for editor in editing when editor in (lastDiff.updators ? []))
  if relevant.length
    MessagesDiff.update lastDiff._id,
      $addToSet: finished: $each: relevant

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

@canCoauthorsMod = (message, coauthorsMod, client = Meteor.isClient, user = Meteor.user()) ->
  ## Adding coauthors requires no additional permission.
  ## Removing coauthors can be done in the following situations:
  ##   * User is a superuser.
  ##   * User is the coauthor being removed (self-removal).
  ##   * Coauthor being removed isn't an author
  ##     (presumably the user is acting as a scribe).
  if coauthorsMod.$addToSet?
    true
  else if coauthorsMod.$pull?
    unless canSuper message.group, client, user
      for coauthor in coauthorsMod.$pull
        if escapeUser(coauthor) of message.authors and coauthor != user.username
          return false
    true

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
  'coauthors'
  'access'
]

export messageExtraFields = [
  'editing'
  #'finished'
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

matchStringSetMod = Match.Optional Match.OneOf
  $addToSet: [String]  # add strings
,
  $pull: [String]      # remove strings

doStringSetMod = (message, old, key, mod) ->
  if mod.$addToSet?   # add strings
    message[key] =
      if old[key]?
        message[key] = _.clone old[key]
      else
        []  # 'access' field in particular doesn't exist initially
    for string in mod.$addToSet
      message[key].push string if string not in message[key]
  else if mod.$pull?  # remove strings
    message[key] = _.without old[key], ...mod.$pull
  else
    throw new Meteor.Error 'doStringSetModifier.invalidMod',
      "Unknown modifier type '#{_keys mod}'"

## The following should be called directly only on the server;
## clients should use the corresponding method.
_messageUpdate = (id, message, authors = null, old = null) ->
  ## Turn off optimistic UI to avoid flicker and false sense of updates :-(
  return unless Meteor.isServer

  ## Compare with 'old' if provided (in cases when it's already been
  ## fetched by the server); otherwise, load id from Messages.
  old = Messages.findOne id unless old?

  ## authors is set only when internal to server, in which case we bypass
  ## authorization checks, which already happened in messageEditStart.
  unless authors?
    ## If authors == null, we're guaranteed to be in a method, so we
    ## can use Meteor.user().
    user = Meteor.user()
    unless user?
      throw new Meteor.Error 'messageUpdate.anonymous',
        "Need to be logged in to edit messages (so we can track coauthors!)"
    check Meteor.userId(), String
    authors = [user.username]
    unless canEdit old, false, user
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
    finished: Match.Optional Boolean
    coauthors: matchStringSetMod
    access: matchStringSetMod
  ## `coauthors` and `access` are given as special instructions for
  ## transactional behavior and extra permission checking.
  if (coauthorsMod = message.coauthors)?
    unless canCoauthorsMod old, coauthorsMod, false, user
      throw new Meteor.Error 'messageUpdate.authorCoauthor',
        "Insufficient permissions to remove coauthors who authored message '#{id}' in group '#{old.group}'"
    doStringSetMod message, old, 'coauthors', coauthorsMod
    unless message.coauthors.length
      throw new Meteor.Error 'messageUpdate.zeroCoauthors',
        "Cannot remove last coauthor of message '#{id}'"
  if (accessMod = message.access)?
    doStringSetMod message, old, 'access', accessMod
  ## `finished` is a special indicator to mark the diff as finished,
  ## when making edits from outside editing mode.
  finished = message.finished
  delete message.finished

  ## Don't update if there aren't any actual differences.
  difference = false
  for own key of message
    unless _.isEqual old[key], message[key]
      difference = true
      break
  return unless difference

  message.updators = authors
  ## Updating a message's title, body, or file give you authorship on the
  ## message.  Updates that modify authorship or access; otherwise, you
  ## couldn't e.g. remove your own authorship.  Also, maintaining others'
  ## authorship or access is administrative, so doesn't feel worthy of your
  ## own authorship.  In that spirit, neither do tags and labels.
  #unless coauthorsMod? or accessMod?
  if message.title? or message.body? or message.file?
    for author in authors
      if author not in (message.coauthors ? old.coauthors)
        message.coauthors ?= _.clone old.coauthors
        message.coauthors.push author
  ## Don't simulate changes involving date, which will be invalidated by server
  if Meteor.isServer
    now = new Date
    if message.published == true
      message.published = now
    message.updated = now
    diff = _.clone message
    for author in authors
      message["authors.#{escapeUser author}"] = now
  Messages.update id,
    $set: message
  if Meteor.isServer
    diff.id = id
    diff.finished = authors if finished
    diffid = MessagesDiff.insert diff
    diff._id = diffid
    #_submessagesChanged old.root ? id
    if not old.root? or _consideredSubmessage message, old
      ## In this special case, we can efficiently simulate the behavior of
      ## _submessagesChanged via a direct update to the root:
      rootUpdate = $max: submessageLastUpdate: message.updated
      if old.root? and not _consideredSubmessage old
        rootUpdate.$inc = submessageCount: 1  ## considered a new submessage
      Messages.update (old.root ? id), rootUpdate
    else if _consideredSubmessage old
      ## If this message is no longer considered a submessage, we need to
      ## recompute from scratch in order to find the new last update.
      _submessagesChanged old.root ? id
    notifyMessageUpdate message, old
    ## Check for removed coauthors/access that should no longer be editors.
    ## (Let them stay as editors if they made the change and can still edit.)0
    for other in (coauthorsMod?.$pull ? []).concat (accessMod?.$pull ? [])
      if other in (old.editing ? []) and
         (other != user?.username or not canEdit id, false, findUsername user)
        _messageEditStop id, other
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
    group = position ? cmsg.group
    position = null  ## henceforth, position should be an integer or null
    unless findGroup group
      throw new Meteor.Error 'messageParent.badGroup',
        "Attempt to reparent #{child} into unknown group #{group}"
    root = null

  #unless canEdit(child) and canPost group, parent
  unless canParent child, parent, group
    throw new Meteor.Error 'messageParent.unauthorized',
      "Insufficient privileges to reparent message #{child} into #{parent}"

  ## Check before creating a cycle in the parent pointers.
  ## This can happen only if we are making the message nonroot (parent
  ## nonnull), and either the child has children of its own or parent is child.
  if parent?
    if parent == child
      throw new Meteor.Error 'messageParent.cycle',
        "Attempt to make #{child} its own parent"
    if cmsg.children?.length # optimization for new message
      for ancestor from ancestorMessages pmsg, false # already checked parent
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
  if parent == oldParent == null and group == cmsg.group
    return  ## no-op, root case
  if parent?
    _messageAddChild child, parent, position
  msgUpdate = {}
  msgOnlyUpdate = {}
  descendantUpdate = {}
  if root != cmsg.root
    msgUpdate.root = root
    descendantUpdate.root = root ? child
  if group != cmsg.group
    msgUpdate.group = group
    descendantUpdate.group = group
    ## First MessagesDiff has the initial group; add Diff if it changes.
    ## (Unclear whether we should track group at all, though.)
    now = new Date
    username = Meteor.user().username
    MessagesDiff.insert
      id: cmsg._id
      group: cmsg.group
      updated: now
      updators: [username]
    msgOnlyUpdate["authors.#{escapeUser username}"] = now
  unless _.isEmpty msgUpdate  # update root and/or group
    Messages.update child,
      $set: _.extend msgOnlyUpdate, msgUpdate
    EmojiMessages.update
      message: child
    ,
      $set: msgUpdate
    ,
      multi: true
    ## Update descendants to use new root and/or group
    descendants = descendantMessageIds cmsg
    if descendants.length > 0
      Messages.update
        _id: $in: descendants
      ,
        $set: descendantUpdate
      ,
        multi: true
      EmojiMessages.update
        message: $in: descendants
      ,
        $set: descendantUpdate
      ,
        multi: true
    ## Update group of files for moved message and its descendants
    if group != cmsg.group
      fileIds = _.uniq(
        MessagesDiff.find
          id: $in: [cmsg._id].concat descendants
          file: $exists: true
        .map (diff) -> new Meteor.Collection.ObjectID diff.file
      )
      if fileIds.length > 0
        Files.update
          _id: $in: fileIds
        ,
          $set: "metadata.group": group
        , multi: true
    #if cmsg.root?
    #  ## If we move a nonroot message to have new root, update descendants.
    #else if cmsg.children?.length
    #  ## To reparent root message (with children),
    #  ## change the root of all descendants.
    #  Messages.update
    #    root: child
    #  ,
    #    $set: update  # root: root ? child  ## actually must be root
    #  ,
    #    multi: true
    #  EmojiMessages.update
    #    root: child
    #  ,
    #    $set: update  # root: root ? child  ## actually must be root
    #  ,
    #    multi: true
    _noLongerRoot child if root? and not cmsg.root?
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

_messageEditStop = (id, username = Meteor.user()?.username) ->
  ## `username` can only be specified when called internal to the server.
  ## When updating this method, you might also want to update the "extreme"
  ## form in `updateStopTimer` above.
  unless username?
    throw new Meteor.Error 'messageEditStop.noUser',
      "Cannot stop editing when not logged in"
  ## We used to do the following update in client too, to do
  ## speculatively, but it seems problematic for now.
  return unless Meteor.isServer
  Messages.update id,
    $pull: editing: username
  unless Messages.findOne(id).editing?.length  ## removed last editor
    Meteor.clearTimeout stopTimers[id]
    editor2messageUpdate id, [username]
    ShareJS.model.delete id
  ## If this user was involved in the last edit to this message,
  ## mark it as "finished" version for the user.
  finishLastDiff id, [username]

if Meteor.isServer
  editorTimers = {}
  stopTimers = {}

  ## Remove all editors on server start, so that we can restart listeners.
  ## Update finished field accordingly, but don't prevent finished bootstrap.
  needBootstrap = not MessagesDiff.findOne finished: $exists: true
  Messages.find().forEach (message) ->
    if message.editing?.length
      finishLastDiff message._id, message.editing unless needBootstrap
      Messages.update message._id,
        $unset: editing: ''

  onExit ->
    console.log 'EXITING'

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
    updateStopTimer id
    Meteor.clearTimeout editorTimers[id]
    editors = findMessage(id).editing
    editorTimers[id] = Meteor.setTimeout ->
      editor2messageUpdate id, editors
    , idleUpdate

  updateStopTimer = (id) ->
    Meteor.clearTimeout stopTimers[id]
    stopTimers[id] = Meteor.setTimeout ->
      ## This code is like an extreme form of `messageEditStop` below:
      editing = Messages.findOne(id).editing ? []
      editor2messageUpdate id, editing
      Messages.update id,
        $unset: editing: ''
      finishLastDiff id, editing
      ShareJS.model.delete id
    , idleStop

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
      finished: Match.Optional Boolean
    ## `finished` is a special indicator to mark the diff as finished,
    ## when making edits from outside editing mode.
    finished = message.finished
    delete message.finished
    user = Meteor.user()
    unless canPost group, parent, user
      throw new Meteor.Error 'messageNew.unauthorized',
        "Insufficient permissions to post new message in group '#{group}' under parent '#{parent}'"
    if parent and not pmsg = findMessage parent
      throw new Meteor.Error 'messageNew.noParent',
        "Attempt to post child message of invalid message '#{parent}'"
    root = findMessageRoot pmsg
    checkPrivacy message.private, root, user
    unless message.private?
      ## If root says private only, default is to be private.
      ## Otherwise, match parent.
      if root?.threadPrivacy? and 'public' not in root.threadPrivacy
        message.private = true
      else if parent?
        message.private = pmsg.private if pmsg.private?
      ## Old default: public if available, private otherwise
      #if root?.threadPrivacy? and 'public' not in root.threadPrivacy
      #  message.private = true
    ## "Reply All" behavior: Initial access for a private message
    ## includes all coauthors and access of parent message,
    ## except for the actual author of this message which isn't needed.
    if message.private
      message.access = _.clone pmsg.coauthors
      for username in pmsg.access ? []
        message.access.push username unless username in message.access
      message.access = _.without message.access, user.username
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
    message.coauthors = [user.username]
    ## Content specific to Messages, not MessagesDiff
    diff = _.clone message
    message.creator = user.username
    message.created = now
    message.authors =
      "#{escapeUser user.username}": now
    #message.parent = parent         ## use children, not parent
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
    diff.finished = diff.updators if finished
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
    ## `child` is the message to reparent.
    ## `parent` is the new parent, or null means make `child` a root message.
    ## `position` normally specifies the integer index to place in parent's
    ## children list.  When `parent` is null, though, it can specify a group
    ## to make `child` the root of (when you're superuser).
    ##
    ## Notably, disabling `oldParent` setting and `importing` options of
    ## `_messageParent` are not allowed from client, only internal to server.
    check Meteor.userId(), String
    check parent, Match.OneOf String, null
    if parent?
      check position, Match.Maybe Number
    else
      check position, Match.Maybe String
    return if @isSimulation  # don't show change until server updated
    _messageParent child, parent, position

  messageEditStart: (id) ->
    check Meteor.userId(), String
    return if @isSimulation
    unless canEdit id, false
      throw new Meteor.Error 'messageEditStart.unauthorized',
        "Insufficient permissions to edit message '#{id}'"
    old = Messages.findOne id
    return unless old?
    unless old.editing?.length
      ShareJS.model.delete id
      ShareJS.initializeDoc id, old.body ? ''
      ShareJS.model.listen id, Meteor.bindEnvironment (opData) ->
        delayedEditor2messageUpdate id
      updateStopTimer id
    ## We used to do the following update in client too, to do
    ## speculatively, but it seems problematic for now.
    Messages.update id,
      $addToSet: editing: Meteor.user().username

  messageEditStop: (id) ->
    _messageEditStop id

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
      coauthors: Match.Optional [String]
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
      coauthors: Match.Optional [String]
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
    message.updators = diffs[diffs.length-1].updators
    message.importer = me
    message.imported = now
    ## Automatically set 'authors' to have the latest update for each author.
    message.authors = {}
    for diff in diffs
      for author in diff.updators
        message.authors[author] = diff.updated
    diff?.finished = diff.updators  ## last diff gets "finished" flag
    ## If caller doesn't bother setting coauthors, extrapolate from authors:
    message.coauthors ?= _.keys message.authors
    diff[0].coauthors ?= message.coauthors
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
  return {} unless root._id?
  return {} if root.root?  # doesn't work on nonroot messages
  messages = groupSortedBy root.group, groupDefaultSort(root.group),
    fields:
      title: 1
      group: 1
  messages = messages.fetch() if messages.fetch?
  ids = (message._id for message in messages)
  index = ids.indexOf root._id
  return {} unless index >= 0
  neighbors = {}
  neighbors.prev = messages[index-1] if index > 0
  neighbors.next = messages[index+1] if index < messages.length - 1
  neighbors

## Given a message object, fetch all diffs for that message and construct the
## entire sequence history of message objects over time,
## coalescing diffs via the implicit $set of each diff.
## Includes recomputation of `authors` map along the timeline
## and inheritance of `creator` and `created` from the message object
## (despite that not being stored explicitly in diffs).
## Each new message object has `_id` equal to the message's `_id`,
## and an extra `diffId` key for the diff's `_id` field.
@messageDiffsExpanded = (message) ->
  message = findMessage message
  diffs = MessagesDiff.find
    id: message._id
  ,
    sort: ['updated']
  .fetch()
  ## Accumulate diffs
  for diff, i in diffs
    diff.diffId = diff._id
    diff._id = message._id
    if i == 0  # first diff
      diff.creator = message.creator
      diff.created = message.created
      diff.authors = {}
    else  # later diff
      diff.authors = _.extend {}, diffs[i-1].authors  # avoid aliasing
      ## Inherit all previous keys except 'finished'
      for own key, value of diffs[i-1] when key != 'finished'
        unless key of diff
          diff[key] = value
    for author in diff.updators ? []
      diff.authors[escapeUser author] = diff.updated
  diffs
