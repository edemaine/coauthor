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
    canAdmin routeGroupOrWild()
  inUsers: ->
    Router.current().route.getName() == 'users'
  creditsWide: ->
    Router.current().route.getName() != 'message'

Template.registerHelper 'couldSuper', ->
  canSuper routeGroupOrWild(), false

Template.registerHelper 'super', ->
  Session.get 'super'

Template.layout.events
  'click .superButton': (e) ->
    e.preventDefault()
    e.stopPropagation()
    Session.set 'super', not Session.get 'super'
