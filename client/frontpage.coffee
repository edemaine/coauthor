Template.frontpage.helpers
  groups: ->
    Groups.find()
  groupcount: ->
    Groups.find().count()
  canSuper: ->
    canSuper wildGroup

Template.frontpage.events
  'click .recomputeAuthorsButton': ->
    Meteor.call 'recomputeAuthors' #, wildGroup
