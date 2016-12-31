@Subscribe = new SubsManager

Router.configure
  layoutTemplate: 'layout'
  loadingTemplate: 'loading'
  subscriptions: -> [
    Subscribe.subscribe 'groups'
  ]

Router.route '/:group/m/:message',
  #Session.set 'group', Groups.findOne
  #  name: @params.group
  #if Session.get 'group'
  #  Session.set 'message', Messages.findOne
  #    url: @params.message
  #  if Session.get 'message'
  #    @render 'message'
  #  else
  #    @render 'badMessage'
  #else
  #  @render 'badGroup'
  #,
  name: 'message'
  template: 'messageMaybe'
  subscriptions: -> [
    Subscribe.subscribe 'messages', @params.group
    Subscribe.subscribe 'messages.subscribers', @params.message
  ]
  data: ->
    Messages.findOne @params.message
  #dataNotFoundTemplate: 'NotFound'

Router.route '/:group',
  #Session.set 'group', Groups.findOne {name: @params.group}
  #if Session.get 'group'
  #  @render 'group'
  #else
  #  @render 'badGroup'
  #,
  name: 'group'
  subscriptions: -> [
    Subscribe.subscribe 'messages', @params.group
    Subscribe.subscribe 'groups.members', @params.group
  ]
  data: ->
    group: @params.group

Router.route '/:group/+:sortBy?',
  name: 'group.sorted.forward'
  template: 'group'
  subscriptions: -> [
    Subscribe.subscribe 'messages', @params.group
    Subscribe.subscribe 'groups.members', @params.group
  ]
  data: ->
    group: @params.group

Router.route '/:group/-:sortBy?',
  name: 'group.sorted.reverse'
  template: 'group'
  subscriptions: -> [
    Subscribe.subscribe 'messages', @params.group
    Subscribe.subscribe 'groups.members', @params.group
  ]
  data: ->
    group: @params.group

Router.route '/:group/since/:since',
  name: 'since'
  subscriptions: -> [
    Subscribe.subscribe 'messages', @params.group
  ]
  data: ->
    group: @params.group
    since: @params.since

Router.route '/:group/live/:limit',
  name: 'live'
  subscriptions: -> [
    Subscribe.subscribe 'messages', @params.group
  ]
  data: ->
    group: @params.group
    limit: @params.limit

Router.route '/:group/live',
  name: 'live.default'
  template: 'live'
  subscriptions: -> [
    Subscribe.subscribe 'messages', @params.group
  ]
  data: ->
    group: @params.group
    limit: 50

Router.route '/:group/author/:author',
  name: 'author'
  subscriptions: -> [
    Subscribe.subscribe 'messages', @params.group
  ]
  data: ->
    group: @params.group
    author: @params.author

@wildGroupRoute = 'GLOBAL'

Router.route '/:group/users',
  name: 'users'
  subscriptions: -> [
    Subscribe.subscribe 'users'
  ]
  data: ->
    group: routeGroup()

Router.route '/:group/settings',
  name: 'settings'

Router.route '/',
  name: 'frontpage'
