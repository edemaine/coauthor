Template.frontpage.helpers
  groups: ->
    Groups.find()
  groupcount: ->
    Groups.find().count()
  canSuper: ->
    canSuper wildGroup

Template.frontpage.events
  'click .recomputeAuthorsButton': ->
    Meteor.call 'recomputeAuthors', (error, result) ->
      if error
        console.error 'recomputeAuthors:', error
      else
        console.log 'recomputeAuthors done!'
  'click .recomputeRootsButton': ->
    Meteor.call 'recomputeRoots', (error, result) ->
      if error
        console.error 'recomputeRoots:', error
      else
        console.log 'recomputeRoots done!'
