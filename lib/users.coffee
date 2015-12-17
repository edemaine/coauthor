@findUser = (userId) ->
  if userId?
    Meteor.users.findOne(userId) ? {}
  else
    {}

## Need to escape dots in usernames.
@escapeUser = escapeGroup
@unescapeUser = unescapeGroup

if Meteor.isServer
  Meteor.publish 'users', (group) ->
    @autorun ->
      if groupRoleCheck group, 'admin', findUser @userId
        Meteor.users.find {},
          roles: 1
      else
        @ready()
    null

  Meteor.publish 'userData', ->
    @autorun ->
      if @userId
        Meteor.users.find
          _id: @userId
        , fields:
            roles: 1
      else
        @ready()
    null
else  ## client
  Meteor.subscribe 'userData'
