@wildGroup = '*'
@anonymousUser = '*'
@readAllUser = '[READ-ALL]'
@allRoles = ['read', 'post', 'edit', 'super', 'admin']

@escapeGroup = escapeKey
@unescapeGroup = unescapeKey
@validGroup = (group) ->
  validKey(group) and group.charAt(0) != '*' and group.trim().length > 0

@sortKeys = ['title', 'creator', 'published', 'updated', 'posts', 'emoji',
             'subscribe']

@defaultSort =
  key: 'published'
  reverse: true

titleDigits = 10
@titleSort = (title) ->
  title = title.title if title.title?
  title.toLowerCase().replace /\d+/g, (n) -> s.lpad n, titleDigits, '0'

@Groups = new Mongo.Collection 'groups'

if Meteor.isServer
  Groups._ensureIndex [['name', 1]]

@findGroup = (group) ->
  return group unless group?
  return group if group.name?
  Groups.findOne
    name: group

@groupDefaultSort = (group) ->
  findGroup(group)?.defaultSort ? defaultSort

@groupAnonymousRoles = (group) ->
  findGroup(group)?.anonymous ? []

@groupRoleCheck = (group, role, user = Meteor.user()) ->
  ###
  `group` can be a string (which will incur a findGroup) or a group object.
  Also, `group` may be `wildGroup` to check specifically for global role.
  If e.g. in Meteor.publish handler, pass in user: findUser userId
  ###
  if user == readAllUser
    return role == 'read'
  role in (user?.roles?[wildGroup] ? []) or
  role in (user?.roles?[escapeGroup(group?.name ? group)] ? []) or
  role in groupAnonymousRoles group

@messageRoleCheck = (group, message, role, user = Meteor.user()) ->
  groupRoleCheck(group, role, user) or
  (message and
   (role in (user?.rolesPartial?[escapeGroup(group?.name ? group)]?[message2root message] ? [])))

@groupPartialMessagesWithRole = (group, role, user = Meteor.user()) ->
  group = group.name if group.name?
  message \
  for own message, roles of user?.rolesPartial?[escapeGroup group] ? [] \
  when role in roles

@memberOfGroup = (group, user = Meteor.user()) ->
  escaped = escapeGroup (group?.name ? group)
  not _.isEmpty(user?.roles?[escaped]) or
  not _.isEmpty(user?.rolesPartial?[escaped])

## General group features are available for all readable groups (including
## anonymous groups) and all groups of which you are a full or partial member.
@memberOfGroupOrReadable = (group, user = Meteor.user()) ->
  memberOfGroup(group, user) or
  groupRoleCheck group, 'read', user

## List all groups that the user is a member of.
## (Mimicking memberOfGroup above.)
@memberOfGroups = (user = Meteor.user()) ->
  groups = (group for own group, roles of user?.roles ? {} \
                  when not _.isEmpty roles)
  .concat (group for group, msgs of user?.rolesPartial ? {} \
                 when not _.isEmpty msgs)
  for group in groups
    continue if group == wildGroup
    unescapeGroup group

if Meteor.isServer
  @accessibleGroups = (userId) ->
    user = findUser userId  ## possibly anonymous
    if not _.isEmpty user?.roles?[wildGroup]  ## global super user
      Groups.find()
    else  ## groups accessible by this user or by anonymous
      Groups.find
        $or: [
          #anonymous: 'read'
          anonymous: $nin: [null, []]
        ,
          name: $in: memberOfGroups user
        ]
  @accessibleGroupNames = (userId) ->
    accessibleGroups(userId).map (group) -> group.name

  Meteor.publish 'groups', ->
    @autorun ->
      accessibleGroups @userId

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
    $or: [
      roles: $exists: true
    ,
      rolesPartial: $exists: true
    ]
  ,
    fields:
      roles: true
      rolesPartial: true
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
      groupData = findGroup group
      user = findUser @userId
      ## Publish members of all readable groups (including anonymous groups)
      ## and all groups of which you are a full or partial member.
      if memberOfGroupOrReadable groupData, user
        Meteor.users.find
          username: $in: groupMembers groupData
        ,
          fields:
            username: true
            profile: true
            emails: true  ## necessary to know whether email address verified
            roles: true  ## necessary to know who can see messages
            rolesPartial: true  ## necessary to know who can see messages
      else
        @ready()

@groupMembers = (group) ->
  findGroup(group)?.members ? []
  ## Mimic memberOfGroup above
  #Meteor.users.find
  #  "roles.#{escapeGroup group}":
  #    $exists: true
  #    $ne: []
  #, options

@sortedGroupMembers = (group) ->
  _.sortBy groupMembers(group), userSortKey

@groupFullMembers = (group, options) ->
  Meteor.users.find
    "roles.#{escapeGroup group}":
      $exists: true
      $ne: []
  , options

@sortedGroupFullMembers = (group, options) ->
  _.sortBy groupFullMembers(group, options).fetch(), userSortKey

@groupPartialMembers = (group, options) ->
  Meteor.users.find
    "rolesPartial.#{escapeGroup group}":
      $exists: true
      $ne: {}
  , options

@sortedGroupPartialMembers = (group, options) ->
  _.sortBy groupPartialMembers(group, options).fetch(), userSortKey

Meteor.methods
  setRole: (group, message, user, role, yesno) ->
    check group, String
    check message, Match.Maybe String
    check user, String
    check role, String
    check yesno, Boolean
    #console.log 'setRole', group, message, user, role, yesno
    unless messageRoleCheck group, message, 'admin'
      throw new Meteor.Error 'setRole.unauthorized',
        "You need 'admin' permissions to set roles in group '#{group}'"
    if user == anonymousUser
      if message
        throw new Meteor.Error 'setRole.anonymousMessage',
          "Message-specific role setting not allowed for anonymous user"
      if yesno
        Groups.update
          name: group
        , $addToSet: anonymous: role
      else
        Groups.update
          name: group
        , $pull: anonymous: role
    else
      if message
        op =
          "rolesPartial.#{escapeGroup group}.#{message}": role
      else
        op =
          "roles.#{escapeGroup group}": role
      if yesno
        Meteor.users.update
          username: user
        , $addToSet: op
      else
        Meteor.users.update
          username: user
        , $pull: op
        ## Check for now-empty rolesPartial for a particular message, and if
        ## so, eliminate role array.  This lets us more easily check whether
        ## a user has any partial roles in a given group.
        if message
          Meteor.users.update
            username: user
            "rolesPartial.#{escapeGroup group}.#{message}": []
          , $unset: "rolesPartial.#{escapeGroup group}.#{message}": ''
        #if message and
        #   _.isEmpty findUsername(user)?.rolesPartial?[group]?[message]
        #  Meteor.users.update
        #    username: user
        #  , $unset: "rolesPartial.#{escapeGroup group}.#{message}": ''

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

  groupWeekStart: (group, weekStart) ->
    check group, String
    check weekStart, Match.Where (x) -> x in [0, 1, 2, 3, 4, 5, 6]
    unless groupRoleCheck group, 'super'
      throw new Meteor.Error 'groupWeekStart.unauthorized',
        "You need 'super' permissions to set week start in group '#{group}'"
    Groups.update
       name: group
     ,
       $set: weekStart: weekStart

  groupNew: (group) ->
    check Meteor.userId(), String
    username = Meteor.user().username
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
      members: []  ## will be updated by role change below
      created: new Date
      creator: username
    ## Give the group creator full access rights to the group,
    ## so that they don't need global admin permissions to tweak it.
    Meteor.users.update
      username: username
    , $addToSet: "roles.#{escapeGroup group}": $each: allRoles

  groupRename: (groupOld, groupNew) ->
    check groupOld, String
    check groupNew, String
    unless groupRoleCheck wildGroup, 'super'
      throw new Meteor.Error 'groupRename.unauthorized',
        "You need global 'super' permissions to rename a group '#{groupOld}'"
    unless validGroup groupOld
      throw new Meteor.Error 'groupRename.invalid',
        "Group name '#{groupOld}' is invalid"
    if findGroup(groupNew)?
      throw new Meteor.Error 'groupRename.exists',
        "Attempt to rename group into '#{groupNew}' which already exists"
    Groups.update
      name: groupOld
    ,
      $set: name: groupNew
    , multi: true
    for db in [Messages, MessagesDiff, Notifications, Tags]
      db.update
        group: groupOld
      ,
        $set: group: groupNew
      , multi: true
    for copy in ['old', 'new']
      Notifications.update
        "#{copy}.group": groupOld
      ,
        $set: "#{copy}.group": groupNew
      , multi: true
    Files.update
      'metadata.group': groupOld
    ,
      $set: "metadata.group": groupNew
    , multi: true
    Meteor.users.find
      "roles.#{escapeGroup groupOld}": $exists: true
    .forEach (user) ->
      roles = user.roles[escapeGroup groupOld]
      Meteor.users.update user._id,
        $unset: "roles.#{escapeGroup groupOld}": ''
        $set: "roles.#{escapeGroup groupNew}": roles

@groupSortedBy = (group, sort, options, user = Meteor.user()) ->
  query = accessibleMessagesQuery group, user
  query.root = null
  options = {} unless options?
  if sort?
    mongosort =
      switch sort.key
        when 'posts'
          'submessageCount'
        when 'updated'
          'submessageLastUpdate'
        else
          sort.key
    #options.sort = [[mongosort, if sort.reverse then 'desc' else 'asc']]
    if options.fields
      options.fields[mongosort] = true
      if sort.key == 'subscribe'  ## fields needed for subscribedToMessage
        options.fields.group = true
        options.fields.root = true
      options.fields.deleted = true
      options.fields.minimized = true
      options.fields.published = true
  msgs = Messages.find query, options
  if sort?
    switch sort.key
      when 'title'
        key = (msg) -> titleSort msg.title
      when 'creator'
        key = (msg) -> userSortKey msg.creator
      when 'subscribe'
        key = (msg) -> subscribedToMessage msg
      when 'emoji'
        key = (msg) ->
          sum = 0
          if msg.emoji
            for emoji, users of msg.emoji
              sum += users.length
          sum
      else
        key = mongosort
        #key = (msg) -> msg[mongosort]
    if key?
      msgs = msgs.fetch()
      msgs = _.sortBy msgs, key
      msgs.reverse() if sort.reverse
      msgs = _.sortBy msgs,
        (msg) ->
          weight = 0
          weight += 4 if msg.deleted  ## deleted messages go very bottom
          weight += 2 if msg.minimized  ## minimized messages go bottom
          weight -= 1 unless msg.published  ## unpublished messages go top
          weight
  msgs
