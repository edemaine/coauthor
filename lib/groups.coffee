import {check, Match} from 'meteor/check'
import {Mongo} from 'meteor/mongo'

import {escapeKey, unescapeKey, validKey} from './escape'
import {messagesSortedBy, mongoSort} from './messages'
import {profilingStartup} from './profiling'
import {sortUsers} from './users'

@wildGroup = '*'
export anonymousUser = '*'
export readAllUser = '[READ-ALL]'
export allRoles = ['read', 'post', 'edit', 'super', 'admin']

@escapeGroup = escapeKey
@unescapeGroup = unescapeKey
@validGroup = (group) ->
  validKey(group) and group.charAt(0) != '*' and group.trim().length > 0

export sortKeys = ['title', 'creator', 'published', 'updated', 'posts', 'emoji', 'subscribe']

export defaultSort = '-published'

titleDigits = 10
@titleSort = (title, format) ->
  title = title.title if title.title?
  until title == oldTitle
    oldTitle = title
    title = title.replace /^\s+/, ''
    # Remove math openers
    title = title.replace ///
      ^ ( \$ | \\ [\(\[] ) (?= .*? \1 )
    ///, ''
    if format == 'markdown'
      # Remove Markdown formatting openers
      title = title.replace ///
        ^ ( [*_]+ | ~~ ) (?= \S ( .*? \S )? \1 ) |
        ^ ( `+ ) (?= .*? \1 )
      ///, ''
  # Remove leading backslashes (e.g. \alpha -> alpha)
  title.replace /^\\+/, ''
  # Case insensitive
  .toLowerCase()
  # Make 10 sort after 9 by left-padding all numbers with zeros
  .replace /\d+/g, (n) -> s.lpad n, titleDigits, '0'

@Groups = new Mongo.Collection 'groups'

if Meteor.isServer
  Groups.createIndex [['name', 1]]

@findGroup = (group) ->
  return group unless group?
  return group if group.name?
  Groups.findOne
    name: group
  , sort: name: 1

export groupDefaultSort = (group) ->
  try
    parseSort findGroup(group)?.defaultSort ? defaultSort
  catch
    console.warn "Invalid default group sort: #{JSON.stringify findGroup(group)?.defaultSort}"
    parseSort defaultSort

sortRegex = new RegExp "^([+\\- ])(#{sortKeys.join '|'}|tag.(?:[^+\\- \\\\]|\\\\.)+)"
export parseSort = (sort) ->
  return [] unless sort
  sorts =
    while (match = sort.match sortRegex)?
      sort = sort[match[0].length..]  # advance to next portion to parse
      key: match[2].replace /\\(.)/g, '$1'
      reverse: match[1] == '-'  # + turns into space which gets treated as +
      #reverse = match[1] == '-'
      #key = match[2]
      #if key.startsWith 'tag.'
      #  key: 'tag'
      #  tag: key[4..]
      #  reverse: reverse
      #else
      #  {key, reverse}
  throw new Error "Invalid sort: #{sort}" if sort
  sorts

export validSort = (sort) ->
  return false unless typeof sort == 'string'
  try
    parseSort sort
    true
  catch
    false

export unparseSort = (parsed) ->
  (for sort in parsed
    (if sort.reverse then '-' else '+') +
    #if sort.key == 'tag'
    #  "tag.#{sort.tag}"
    #else
      sort.key
      .replace /\\/g, '\\\\'
      .replace /[+-]/g, '\\$&'
  ).join ''

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

# Like messageRoleCheck, but where second argument is guaranteed to be root
# (string ID or null).
@rootRoleCheck = (group, root, role, user = Meteor.user()) ->
  groupRoleCheck(group, role, user) or
  (root and
   (role in (user?.rolesPartial?[escapeGroup(group?.name ? group)]?[root] ? [])))

@groupPartialMessagesWithRole = (group, role, user = Meteor.user()) ->
  group = group.name if group.name?
  message \
  for own message, roles of user?.rolesPartial?[escapeGroup group] ? [] \
  when role in roles

@memberOfGroup = (group, user = Meteor.user()) ->
  escaped = escapeGroup (group?.name ? group)
  not _.isEmpty(user?.roles?[escaped]) or
  not _.isEmpty(user?.rolesPartial?[escaped])
@fullMemberOfGroup = (group, user = Meteor.user()) ->
  not _.isEmpty user?.roles?[escapeGroup (group?.name ? group)]
@memberOfThread = (message, user = Meteor.user()) ->
  not _.isEmpty user?.rolesPartial?[escapeGroup message.group]?[message.root ? message._id]

## General group features are available for all visible groups (including
## anonymous groups) and all groups of which you are a full or partial member.
@groupVisible = (group, user = Meteor.user()) ->
  memberOfGroup(group, user) or
  groupRoleCheck(group, 'read', user) or
  groupRoleCheck(group, 'post', user)

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

  profilingStartup 'groups.startup', ->
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
    'Maintaining group membership list'

  Meteor.publish 'groups.members', (group) ->
    check group, String
    @autorun ->
      groupData = findGroup group
      user = findUser @userId
      ## Publish members of all visible groups (including anonymous groups)
      ## and all groups of which you are a full or partial member.
      if groupVisible groupData, user
        Meteor.users.find
          username: $in: groupMembers groupData
        ,
          fields:
            username: true
            profile: true
            emails: true  ## necessary to know whether email address verified
            roles: true  ## necessary to know who can see messages
            rolesPartial: true  ## necessary to know who can see messages
            createdAt: true  ## to show join date
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
  sortUsers groupMembers group

@groupFullMembers = (group, options) ->
  Meteor.users.find
    "roles.#{escapeGroup group}":
      $exists: true
      $ne: []
  , options

@sortedGroupFullMembers = (group, options) ->
  sortUsers groupFullMembers(group, options).fetch()

@groupPartialMembers = (group, options) ->
  Meteor.users.find
    "rolesPartial.#{escapeGroup group}":
      $exists: true
      $ne: {}
  , options

@sortedGroupPartialMembers = (group, options) ->
  sortUsers groupPartialMembers(group, options).fetch()

export messagePartialMembers = (group, message, options) ->
  Meteor.users.find
    "rolesPartial.#{escapeGroup group}.#{message}":
      $exists: true
      $ne: {}
  , options

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
      if group == wildGroup
        throw new Meteor.Error 'setRole.anonymousGlobal',
          "Global role setting not allowed for anonymous user"
      unless messageRoleCheck wildGroup, message, 'admin'
        throw new Meteor.Error 'setRole.unauthorized',
          "You need global 'admin' permissions to set anonymous roles"
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
    check sortBy, Match.Where validSort
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

export groupSortedBy = (group, sorts, options, user = Meteor.user()) ->
  query = accessibleMessagesQuery group, user
  return [] unless query?
  query.root = null  # message roots only
  options = {} unless options?
  for sort in sorts
    #options.sort = [[mongoSort(sort.key), if sort.reverse then 'desc' else 'asc']]
    if options.fields
      options.fields[mongoSort sort.key] = true
      if sort.key == 'subscribe'  ## fields needed for subscribedToMessage
        options.fields.group = true
        options.fields.root = true
      options.fields.deleted = true
      options.fields.minimized = true
      options.fields.pinned = true
      options.fields.published = true
  msgs = Messages.find query, options
  .fetch()
  messagesSortedBy msgs, sorts
