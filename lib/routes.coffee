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

@wildGroupRoute = 'GLOBAL'

Router.route '/:group/users',
  name: 'users'
  template: 'users'
  subscriptions: -> [
    Meteor.subscribe 'users'
  ]
  data: ->
    group: @params.group

Router.route '/',
  name: 'frontpage'
