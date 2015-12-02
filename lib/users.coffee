if Meteor.isServer
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
