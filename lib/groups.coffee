@Groups = new Mongo.Collection 'groups'

if Meteor.isServer
  Meteor.publish 'groups', ->
    Groups.find()
