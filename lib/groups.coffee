@wildGroup = '*'
@anonymousUser = '*'

@validGroup = (group) ->
  group and group.charAt(0) not in ['*', '$']

@Groups = new Mongo.Collection 'groups'

@groupAnonymousRoles = (group) ->
  Groups.findOne
    name: group
  ?.anonymous ? []

@groupRoleCheck = (group, role, userId = null) ->
  ## Note that group may be wildGroup to check specifically for global role.
  if userId?  ## for use in Meteor.publish handler
    user = Meteor.users.findOne userId
  else
    user = Meteor.user()
  role in (user?.roles?[wildGroup] ? []) or
  role in (user?.roles?[group] ? []) or
  role in groupAnonymousRoles group

if Meteor.isServer
  Meteor.publish 'groups', ->
    if @userId?
      user = Meteor.users.findOne @userId
      if not user.roles  ## user has no permissions
        []
      else if 'read' in user.roles[wildGroup] ? []  ## super-reading user
        Groups.find()
      else  ## groups readable by this user or by anonymous
        Groups.find
          $or: [
            {anonymous: 'read'}
            {name: $in: group for group, roles of user.roles ? {} when 'read' in roles}
          ]
    else  ## anonymous user
      Groups.find
        anonymous: 'read'

Meteor.methods
  setRole: (group, user, role, yesno) ->
    check group, String
    check user, String
    check role, String
    check yesno, Boolean
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
        key = 'roles.' + group
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
