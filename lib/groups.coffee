@Groups = new Mongo.Collection 'groups'

@groupsWithRole = (role) ->
  group for own group, roles of Meteor.user().roles ? {} when role in roles

if Meteor.isServer
  Meteor.publish 'groups', ->
    if @userId?
      user = Meteor.users.findOne @userId
      Groups.find
        $or: [
          {anonymous: 'read'}
          {name: $in: group for group, roles of user.roles ? {} when 'read' in roles}
        ]
    else
      Groups.find
        anonymous: 'read'
