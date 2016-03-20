Router.configure
  layoutTemplate: 'layout'
  loadingTemplate: 'loading'
  subscriptions: -> [
    Meteor.subscribe 'groups'
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
  subscriptions: -> [
    Meteor.subscribe 'messages', @params.group
  #  Meteor.subscribe 'comments', @params.message
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
    Meteor.subscribe 'messages', @params.group
  ]
  data: ->
    group: @params.group

Router.route '/:group/+:sortBy?',
  name: 'group.sorted.forward'
  template: 'group'
  subscriptions: -> [
    Meteor.subscribe 'messages', @params.group
  ]
  data: ->
    group: @params.group

Router.route '/:group/-:sortBy?',
  name: 'group.sorted.reverse'
  template: 'group'
  subscriptions: -> [
    Meteor.subscribe 'messages', @params.group
  ]
  data: ->
    group: @params.group

Router.route '/:group/since/:since',
  name: 'since'
  subscriptions: -> [
    Meteor.subscribe 'messages', @params.group
  ]
  data: ->
    group: @params.group
    since: @params.since

Router.route '/:group/live/:limit',
  name: 'live'
  subscriptions: -> [
    Meteor.subscribe 'messages', @params.group
  ]
  data: ->
    group: @params.group
    limit: @params.limit

Router.route '/:group/live',
  name: 'live.default'
  template: 'live'
  subscriptions: -> [
    Meteor.subscribe 'messages', @params.group
  ]
  data: ->
    group: @params.group
    limit: 50

@wildGroupRoute = 'GLOBAL'

Router.route '/:group/users',
  name: 'users'
  subscriptions: -> [
    Meteor.subscribe 'users'
  ]
  data: ->
    group: routeGroup()

Router.route '/:group/settings',
  name: 'settings'

Router.route '/',
  name: 'frontpage'
