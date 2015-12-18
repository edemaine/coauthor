#Dropbox = require 'dropbox'

Meteor.startup ->
  Meteor.users.find
    'services.dropbox.accessToken': $exists: 1
  .forEach (user) ->
    #console.log HTTP.get "https://api.dropbox.com/1/account/info",
    #  headers: Authorization: "Bearer #{user.services.dropbox.accessToken}"
    #.data()
    #console.log HTTP.post 'https://api.dropboxapi.com/1/latest_cursor',
    #  headers: Authorization: "Bearer #{user.services.dropbox.accessToken}"
    #console.log HTTP.post 'https://api.dropboxapi.com/1/delta',
    #  headers: Authorization: "Bearer #{user.services.dropbox.accessToken}"
  #Meteor.users.observe
