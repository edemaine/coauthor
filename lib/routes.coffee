#@Subscribe = Meteor
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
    Subscribe.subscribe 'messages.submessages', @params.message
    Subscribe.subscribe 'messages.root', @params.group
    Subscribe.subscribe 'groups.members', @params.group
    Subscribe.subscribe 'tags', @params.group
  ]
  data: ->
    Messages.findOne @params.message
  #dataNotFoundTemplate: 'NotFound'
  fastRender: true

Router.route '/:group',
  #Session.set 'group', Groups.findOne {name: @params.group}
  #if Session.get 'group'
  #  @render 'group'
  #else
  #  @render 'badGroup'
  #,
  name: 'group'
  subscriptions: -> [
    Subscribe.subscribe 'messages.root', @params.group
    Subscribe.subscribe 'groups.members', @params.group
  ]
  data: ->
    group: @params.group
  fastRender: true

Router.route '/:group/+:sortBy?',
  name: 'group.sorted.forward'
  template: 'group'
  subscriptions: -> [
    Subscribe.subscribe 'messages.root', @params.group
    Subscribe.subscribe 'groups.members', @params.group
  ]
  data: ->
    group: @params.group
  fastRender: true

Router.route '/:group/-:sortBy?',
  name: 'group.sorted.reverse'
  template: 'group'
  subscriptions: -> [
    Subscribe.subscribe 'messages.root', @params.group
    Subscribe.subscribe 'groups.members', @params.group
  ]
  data: ->
    group: @params.group
  fastRender: true

Router.route '/:group/since/:since',
  name: 'since'
  subscriptions: -> [
    Subscribe.subscribe 'messages.since', @params.group, @params.since
    Subscribe.subscribe 'groups.members', @params.group
  ]
  data: ->
    group: @params.group
    since: @params.since
  fastRender: true

Router.route '/:group/live/:limit',
  name: 'live'
  subscriptions: -> [
    Subscribe.subscribe 'messages.live', @params.group, @params.limit
    Subscribe.subscribe 'groups.members', @params.group
  ]
  data: ->
    group: @params.group
    limit: @params.limit
  fastRender: true

defaultLiveLimit = 50

Router.route '/:group/live',
  name: 'live.default'
  template: 'live'
  subscriptions: -> [
    Subscribe.subscribe 'messages.live', @params.group, defaultLiveLimit
    Subscribe.subscribe 'groups.members', @params.group
  ]
  data: ->
    group: @params.group
    limit: defaultLiveLimit
  fastRender: true

Router.route '/:group/author/:author',
  name: 'author'
  subscriptions: -> [
    Subscribe.subscribe 'messages.author', @params.group, @params.author
    Subscribe.subscribe 'groups.members', @params.group
  ]
  data: ->
    group: @params.group
    author: @params.author
  fastRender: true

Router.route '/:group/tag/:tag',
  name: 'tag'
  subscriptions: -> [
    Subscribe.subscribe 'messages.tag', @params.group, @params.tag
    Subscribe.subscribe 'groups.members', @params.group
  ]
  data: ->
    group: @params.group
    tag: @params.tag
  fastRender: true

@wildGroupRoute = 'GLOBAL'

Router.route '/:group/users',
  name: 'users'
  subscriptions: -> [
    Subscribe.subscribe 'users', @params.group
  ]
  data: ->
    group: routeGroup()
  fastRender: true

Router.route '/:group/settings',
  name: 'settings'
  fastRender: true

Router.route '/',
  name: 'frontpage'
  fastRender: true
