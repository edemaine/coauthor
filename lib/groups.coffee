@wildGroup = '*'
@anonymousUser = '*'

@escapeGroup = escapeKey
@unescapeGroup = unescapeKey
@validGroup = (group) ->
  validKey(group) and group.charAt(0) != '*' and group.trim().length > 0

@sortKeys = ['title', 'creator', 'published', 'updated', 'posts', 'subscribe']

@defaultSort =
  key: 'published'
  reverse: true

titleDigits = 10
@titleSort = (title) ->
  title = title.title if title.title?
  title.toLowerCase().replace /\d+/g, (n) -> s.lpad n, titleDigits, '0'

@Groups = new Mongo.Collection 'groups'

@findGroup = (group) ->
  Groups.findOne
    name: group

@groupDefaultSort = (group) ->
  findGroup(group)?.defaultSort ? defaultSort

@groupAnonymousRoles = (group) ->
  findGroup(group)?.anonymous ? []

@groupRoleCheck = (group, role, user = Meteor.user()) ->
  ## Note that group may be wildGroup to check specifically for global role.
  ## If e.g. in Meteor.publish handler, pass in user: findUser userId
  role in (user?.roles?[wildGroup] ? []) or
  role in (user?.roles?[escapeGroup group] ? []) or
  role in groupAnonymousRoles group

if Meteor.isServer
  @readableGroups = (userId) ->
    user = findUser userId
    if not user.roles  ## anonymous user or user has no permissions
      Groups.find
        anonymous: 'read'
    else if 'read' in (user.roles[wildGroup] ? [])  ## super-reading user
      Groups.find()
    else  ## groups readable by this user or by anonymous
      Groups.find
        $or: [
          {anonymous: 'read'}
          {name: $in: (unescapeGroup group for own group, roles of user.roles ? {} when 'read' in roles)}
        ]
  @readableGroupNames = (userId) ->
    names = []
    readableGroups(userId).forEach (group) -> names.push group.name
    names

  Meteor.publish 'groups', ->
    @autorun ->
      readableGroups @userId

  @groupMembers = (group, options) ->
    roles = {}
    roles['roles.' + escapeGroup group] =
      $exists: true
      $ne: []
    Meteor.users.find roles, options

  Meteor.publish 'groups.members', (group) ->
    check group, String
    if groupRoleCheck group, 'read', findUser @userId
      id = findGroup(group)._id
      @autorun ->
        groupMembers group,
          fields:
            username: 1
            profile: 1
      init = true
      @autorun ->
        members =
          members: groupMembers(group, fields: username: 1).map (user) -> user.username
        if init
          init = false
          members.group = group
          @added 'groups.members', id, members
        else
          @changed 'groups.members', id, members
    @ready()

if Meteor.isClient
  @GroupsMembers = new Mongo.Collection 'groups.members'

  @groupMembers = (group) ->
    GroupsMembers.findOne
      group: group
    ?.members ? []

  @sortedGroupMembers = (group) ->
    _.sortBy groupMembers(group), userSortKey

Meteor.methods
  setRole: (group, user, role, yesno) ->
    check group, String
    check user, String
    check role, String
    check yesno, Boolean
    #console.log 'setRole', group, user, role, yesno
    unless groupRoleCheck group, 'admin'
      throw new Meteor.Error 'setRole.unauthorized',
        "You need 'admin' permissions to set roles in group '#{group}'"
    if user == anonymousUser
      if yesno
        Groups.update
          name: group
        , $addToSet: anonymous: role
      else
        Groups.update
          name: group
        , $pull: anonymous: role
    else
      key = 'roles.' + escapeGroup group
      op = {}
      op[key] = role
      if yesno
        Meteor.users.update
          username: user
        , $addToSet: op
      else
        Meteor.users.update
          username: user
        , $pull: op

  groupDefaultSort: (group, sortBy) ->
    check group, String
    check sortBy,
      key: Match.Where (key) -> key in sortKeys
      reverse: Boolean
    unless groupRoleCheck group, 'super'
      throw new Meteor.Error 'groupDefaultSort.unauthorized',
        "You need 'super' permissions to set default sort in group '#{group}'"
    Groups.update
       name: group
     ,
       $set: defaultSort: sortBy

  groupNew: (group) ->
    check group, String
    unless groupRoleCheck wildGroup, 'super'
      throw new Meteor.Error 'groupNew.unauthorized',
        "You need global 'super' permissions to create a new group '#{group}'"
    unless validGroup group
      throw new Meteor.Error 'groupNew.invalid',
        "Group name '#{group}' is invalid"
    if findGroup(group)?
      throw new Meteor.Error 'groupNew.exists',
        "Attempt to create group '#{group}' which already exists"
    Groups.insert
      name: group

@groupSortedBy = (group, sort, options, user = Meteor.user()) ->
  query = accessibleMessagesQuery group, user
  query.root = null
  mongosort =
    switch sort.key
      when 'posts'
        'submessageCount'
      when 'updated'
        'submessageLastUpdate'
      else
        sort.key
  options = {} unless options?
  options.sort = [[mongosort, if sort.reverse then 'desc' else 'asc']]
  if options.fields
    options.fields[mongosort] = 1
  msgs = Messages.find query, options
  switch sort.key
    when 'title'
      key = (msg) -> titleSort msg.title
    when 'creator'
      key = (msg) -> userSortKey msg.creator
    when 'subscribe'
      key = (msg) -> subscribedToMessage msg._id
    else
      key = null
  if key?
    msgs = msgs.fetch()
    msgs = _.sortBy msgs, key
    msgs.reverse() if sort.reverse
  msgs
