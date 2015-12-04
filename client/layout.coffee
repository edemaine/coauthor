Template.layout.helpers
  activeGroup: ->
    data = Template.parentData()
    if routeGroup() == @name
      'active'
    else
      ''
  showUsers: ->
    Router.current().route.getName() != 'users' and
    canAdmin routeGroup()

Template.layout.events
  'click .usersButton': (e) ->
    e.preventDefault()
    e.stopPropagation()
    Router.go 'users', group: @group ? wildGroupRoute

  'click .settingsButton': (e) ->
    e.preventDefault()
    e.stopPropagation()
    Router.go 'settings', group: @group ? wildGroupRoute
