@findUser = (userId) ->
  if userId?
    Meteor.users.findOne(userId) ? {}
  else
    {}

@findUsername = (username) ->
  Meteor.users.findOne
    username: username

@displayUser = (username) ->
  user = findUsername username
  user?.profile?.fullname?.trim?() or username

@linkToAuthor = (group, user, title = "User '#{user}'") ->
  link = pathFor 'author',
    group: group
    author: user
  """<a class="author" href="#{link}" title="#{title.replace /"/g, '&#34;'}">#{displayUser user}</a>"""

## Sort by last name if available
@userSortKey = (username) ->
  display = displayUser username
  space = display.lastIndexOf ' '
  if space >= 0
    display[space+1..] + ", " + display[...space]
  else
    display

@validUsername = (username) ->
  validKey(username) and '@' not in username

## Need to escape dots in usernames.
@escapeUser = escapeKey
@unescapeUser = unescapeKey

if Meteor.isServer
  Meteor.publish 'users', (group) ->
    @autorun ->
      if groupRoleCheck group, 'admin', findUser @userId
        Meteor.users.find {}
        , fields:
            services: false
      else
        @ready()

  Meteor.publish 'userData', ->
    @autorun ->
      if @userId
        Meteor.users.find
          _id: @userId
        , fields:
            roles: true
            'services.dropbox.id': true
      else
        @ready()
else  ## client
  Meteor.subscribe 'userData'

Meteor.methods
  userEditEmail: (email) ->
    check Meteor.userId(), String
    if Meteor.isServer  ## no Accounts on client
      if Meteor.user().emails?[0]?.address?
        Accounts.removeEmail Meteor.userId(), Meteor.user().emails[0].address
      Accounts.addEmail Meteor.userId(), email
