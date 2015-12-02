@wildGroup = '*'

@validGroup = (group) ->
  group and group.charAt(0) not in ['*', '$']

@Groups = new Mongo.Collection 'groups'

@groupAnonymousRoles = (group) ->
  Groups.findOne(group).anonymous

@groupRoleCheck = (group, role, userId = null) ->
  if userId?  ## for use in Meteor.publish handler
    user = Meteor.users.findOne userId
  else
    user = Meteor.user()
  role in (user.roles?[wildGroup] ? []) or
  role in (user.roles?[group] ? []) or
  role in groupAnonymousRoles group

#@groupsWithRole = (role) ->
#  user = Meteor.user()
#  if not user.roles
#    []
#  else if role in user.roles[wildGroup]
#    
#  group for own group, roles of Meteor.user().roles ? {} when role in roles

if Meteor.isServer
  Meteor.publish 'groups', ->
    if @userId?
      user = Meteor.users.findOne @userId
      console.log user.username, user.roles
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
