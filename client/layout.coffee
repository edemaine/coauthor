Template.registerHelper 'uploading', ->
  value for own key, value of Session.get 'uploading'

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
  inUsers: ->
    Router.current().route.getName() == 'users'

Template.registerHelper 'couldSuper', ->
  canSuper routeGroupOrWild(), false

Template.registerHelper 'super', ->
  Session.get 'super'

Template.layout.events
  'click .usersButton': (e) ->
    e.preventDefault()
    e.stopPropagation()
    Router.go 'users', group: routeGroupRoute() ? wildGroupRoute

  'click .settingsButton': (e) ->
    e.preventDefault()
    e.stopPropagation()
    Router.go 'settings', group: routeGroupRoute() ? wildGroupRoute

  'click .superButton': (e) ->
    e.preventDefault()
    e.stopPropagation()
    Session.set 'super', not Session.get 'super'
