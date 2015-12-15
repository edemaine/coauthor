@wildGroup = '*'
@anonymousUser = '*'

@DOT = '[DOT]'
@escapeGroup = (group) ->
  group.replace /\./g, DOT
@unescapeGroup = (group) ->
  group.replace /\[DOT\]/g, '.'
@validGroup = (group) ->
  group and group.charAt(0) not in ['*', '$'] and group.indexOf(DOT) < 0

@Groups = new Mongo.Collection 'groups'

@groupAnonymousRoles = (group) ->
  Groups.findOne
    name: group
  ?.anonymous ? []

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

  Meteor.publish 'groups', ->
    @autorun ->
      readableGroups @userId
    null

Meteor.methods
  setRole: (group, user, role, yesno) ->
    check group, String
    check user, String
    check role, String
    check yesno, Boolean
    #console.log 'setRole', group, user, role, yesno
    if groupRoleCheck group, 'admin'
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
