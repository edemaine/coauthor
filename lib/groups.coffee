@wildGroup = '*'
@anonymousUser = '*'
@readAllUser = '[READ-ALL]'

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
  return group if group.name?
  Groups.findOne
    name: group

@groupDefaultSort = (group) ->
  findGroup(group)?.defaultSort ? defaultSort

@groupAnonymousRoles = (group) ->
  findGroup(group)?.anonymous ? []

@groupRoleCheck = (group, role, user = Meteor.user()) ->
  if user == readAllUser
    return role == 'read'
  ## Note that group may be wildGroup to check specifically for global role.
  ## If e.g. in Meteor.publish handler, pass in user: findUser userId
  role in (user?.roles?[wildGroup] ? []) or
  role in (user?.roles?[escapeGroup group] ? []) or
  role in groupAnonymousRoles group

@memberOfGroup = (group, user = Meteor.user()) ->
  roles = user?.roles?[escapeGroup group]
  roles and roles.length > 0

## List all groups that the user is a member of.
## (Mimicking memberOfGroup above.)
@memberOfGroups = (user = Meteor.user()) ->
  for group, roles of user?.roles ? {}
    continue unless roles.length > 0
    continue if group == wildGroup
    unescapeGroup group

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

  #@groupMembers = (group, options) ->
  #  ## Mimic memberOfGroup above
  #  Meteor.users.find
  #    "roles.#{escapeGroup group}":
  #      $exists: true
  #      $ne: []
  #  , options

  ## Give all groups a 'members' array field, automatically updated to
  ## contain all users that match memberOfGroup defined above.
  ## The initial live query will get all memberships, so reset to empty.
  ## (Also needed because $addToSet only works with fields containing arrays.)
  Groups.update {}
    #members: null
  ,
    $set: members: []
  ,
    multi: true

  membersAddUsername = (username, groups) ->
    if groups.length > 0
      console.log 'adding', username, 'to', groups
      Groups.update
        name: $in: groups
      ,
        $addToSet: members: username
      ,
        multi: true

  membersRemoveUsername = (username, groups) ->
    if groups.length > 0
      Groups.update
        name: $in: groups
      ,
        $pull: members: username
      ,
        multi: true

  Meteor.users.find
    roles: $exists: true
  ,
    fields:
      roles: true
      username: true
  .observe
    added: (user) ->
      membersAddUsername user.username, memberOfGroups user
    removed: (user) ->
      membersRemoveUsername user.username, memberOfGroups user
    changed: (userNew, userOld) ->
      groupsNew = memberOfGroups userNew
      groupsOld = memberOfGroups userOld
      membersRemoveUsername userOld.username, _.difference groupsOld, groupsNew
      membersAddUsername userNew.username, _.difference groupsNew, groupsOld

  Meteor.publish 'groups.members', (group) ->
    check group, String
    @autorun ->
      if groupRoleCheck group, 'read', findUser @userId
        Meteor.users.find
          username: $in: groupMembers group
        ,
          fields:
            username: 1
            profile: 1
      else
        @ready()

@groupMembers = (group) ->
  findGroup(group).members

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
      created: new Date
      creator: Meteor.user().username

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
