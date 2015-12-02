if Meteor.isServer
  Meteor.publish 'users', (group) ->
    if groupRoleCheck group, 'admin', @userId
      Meteor.users.find {},
        roles: 1

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
