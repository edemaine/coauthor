if Meteor.isServer
  Meteor.publish 'users', (group) ->
    if groupRoleCheck group, 'admin', Meteor.users.findOne @userId
      Meteor.users.find {},
        roles: 1
    else
      @ready()

  Meteor.publish 'userData', ->
    if @userId
      Meteor.users.find
        _id: @userId
      , fields:
          roles: 1
    else
      @ready()
else  ## client
  Meteor.subscribe 'userData'
