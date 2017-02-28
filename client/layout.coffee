Template.registerHelper 'uploading', ->
  value for own key, value of Session.get 'uploading'

linkToRoutes =
  users: true
  live: true
  'live.default': true
  author: true
  tag: true
  stats: true
  'stats.userless': true
  settings: true

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
  linkToGroup: ->
    router = Router.current()
    route = Router.current().route.getName()
    if linkToRoutes[route]
      pathFor route,
        _.extend router.params,
          group: @name
    else
      pathFor 'group',
        group: @name
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
