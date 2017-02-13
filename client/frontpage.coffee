Template.frontpage.events
  'click .groupNewButton': ->
    Modal.show 'groupNew'
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

Template.groupNew.events
  'click .groupNewButton': (e, t) ->
    e.preventDefault()
    e.stopPropagation()
    group = t.find('#groupInput').value
    Modal.hide()
    return unless validGroup group  ## ignore blank or otherwise invalid name
    Meteor.call 'groupNew', group, (error, result) ->
      if error
        console.error 'groupNew:', error
      else
        Router.go 'group',
          group: group
  'click .cancelButton': (e) ->
    e.preventDefault()
    e.stopPropagation()
    Modal.hide()
