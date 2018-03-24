Template.frontpage.onCreated ->
  setTitle null

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

groupsSort =
  sort: [['name', 'asc']]

Template.frontpage.helpers
  groupsAnonymous: ->
    Groups.find
      anonymous: $nin: [null, []]
    , groupsSort

  groupsMine: ->
    Groups.find
      name: $in: (unescapeGroup group \
        for own group, roles of Meteor.user()?.roles ? {} \
        when not _.isEmpty roles)
    , groupsSort

  groupsPartial: ->
    full = {}
    for own group, roles of Meteor.user()?.roles ? {}
      full[group] = true if not _.isEmpty roles
    Groups.find
      name: $in: (unescapeGroup group \
        for own group, msgs of Meteor.user()?.rolesPartial ? {} \
        when group not of full and not _.isEmpty msgs)
    , groupsSort

  groupsOther: ->
    Groups.find
      name: $nin: memberOfGroups()  # groupsMine plus groupsPartial
      anonymous: $in: [null, []]
    , groupsSort

Template.groupList.helpers
  ## null op to use `each` with data that's already an array
  groups: -> @

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
