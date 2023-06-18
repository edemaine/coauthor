###
IronRouter routes

When adding a new route here, consider adding it to the `linkToRoutes`
in ../client/layout.coffee, so that changing the group will preserve
the details of the route.
###

# IronRouter builds params on top of an Array.  Array.prototype.group
# wrecks havoc with our use of `group` route param.
delete Array.prototype.group

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
  template: 'message'
  subscriptions: ->
    subs = [
      Subscribe.subscribe 'messages.submessages', @params.message
      #Subscribe.subscribe 'emoji.submessages', @params.message
    ]
    ## Wild message links will get redirected to the proper group; wait on that
    unless @params.group == wildGroup
      subs.push ...[
        Subscribe.subscribe 'messages.root', @params.group
        Subscribe.subscribe 'groups.members', @params.group
        Subscribe.subscribe 'tags', @params.group
        Subscribe.subscribe 'files', @params.group
      ]
    subs
  data: ->
    _id: @params.message
  #dataNotFoundTemplate: 'NotFound'
  action: ->
    if @params.group == wildGroup
      if @ready()
        msg = findMessage @params.message
        if msg?.group
          return @redirect 'message',
            group: msg.group
            message: @params.message
          ,
            replaceState: true
            hash: @params.hash
            query: @params.query
      @render 'messageBad'
    else
      @render()
  fastRender: true

# Want to write /:group/:sortBy?, but this would match everything
for sortChar in ['', '+', '-']
  Router.route '/:group' + (sortChar and "/#{sortChar}:sortBy"),
    name: 'group' + sortChar
    template: 'group'
    subscriptions: -> [
      Subscribe.subscribe 'messages.root', @params.group
      #Subscribe.subscribe 'emoji.root', @params.group
      Subscribe.subscribe 'groups.members', @params.group
      Subscribe.subscribe 'tags', @params.group
    ]
    data: ->
      group: @params.group
    fastRender: true

defaultSince = '1 hour'

Router.route '/:group/since/:since?',
  name: 'since'
  subscriptions: -> [
    Subscribe.subscribe 'messages.since', @params.group, (@params.since ? defaultSince)
    Subscribe.subscribe 'messages.root', @params.group unless @params.group == wildGroup
    Subscribe.subscribe 'groups.members', @params.group
    Subscribe.subscribe 'tags', @params.group
    Subscribe.subscribe 'files', @params.group
  ]
  data: ->
    group: @params.group
    since: @params.since ? defaultSince
  fastRender: true

defaultLiveLimit = 10

Router.route '/:group/live/:limit?',
  name: 'live'
  subscriptions: -> [
    Subscribe.subscribe 'messages.live', @params.group, (@params.limit ? defaultLiveLimit)
    Subscribe.subscribe 'messages.root', @params.group unless @params.group == wildGroup
    Subscribe.subscribe 'groups.members', @params.group
    Subscribe.subscribe 'tags', @params.group
    Subscribe.subscribe 'files', @params.group
  ]
  data: ->
    group: @params.group
    limit: @params.limit ? defaultLiveLimit
  fastRender: true

Router.route '/:group/author/:author',
  name: 'author'
  subscriptions: -> [
    Subscribe.subscribe 'messages.author', @params.group, @params.author
    Subscribe.subscribe 'messages.root', @params.group unless @params.group == wildGroup
    Subscribe.subscribe 'groups.members', @params.group
    Subscribe.subscribe 'tags', @params.group
    Subscribe.subscribe 'files', @params.group
  ]
  data: ->
    group: @params.group
    author: @params.author
  fastRender: true

#Router.route '/:group/tag/:tag',
#  name: 'tag'
#  subscriptions: -> [
#    Subscribe.subscribe 'messages.root', @params.group
#    Subscribe.subscribe 'messages.tag', @params.group, @params.tag
#    Subscribe.subscribe 'groups.members', @params.group
#    Subscribe.subscribe 'files', @params.group
#  ]
#  data: ->
#    group: @params.group
#    tag: @params.tag
#  fastRender: true

Router.route '/:group/stats/:username?',
  name: 'stats'
  template: 'stats'
  subscriptions: -> [
    #Subscribe.subscribe 'messages.author', @params.group, @params.username if @params.username
    Subscribe.subscribe 'messages.all', @params.group
    Subscribe.subscribe 'groups.members', @params.group
  ]
  data: ->
    group: @params.group
    username: @params.username
    unit: @params.query.unit
  fastRender: true

Router.route '/:group/search/:search([^]*)',
  name: 'search'
  subscriptions: -> [
    Subscribe.subscribe 'messages.search', @params.group, @params.search
    Subscribe.subscribe 'messages.root', @params.group unless @params.group == wildGroup
    Subscribe.subscribe 'groups.members', @params.group
    Subscribe.subscribe 'tags', @params.group
    Subscribe.subscribe 'files', @params.group
  ]
  data: ->
    group: @params.group
    search: @params.search
  fastRender: true

Router.route '/:group/users',
  name: 'users'
  subscriptions: -> [
    Subscribe.subscribe 'users', @params.group
    Subscribe.subscribe 'messages.root', @params.group unless @params.group == wildGroup  ## for title links
  ]
  data: ->
    group: @params.group
  fastRender: true

Router.route '/:group/users/:message',
  name: 'users.message'
  template: 'users'
  subscriptions: -> [
    Subscribe.subscribe 'users', @params.group
    Subscribe.subscribe 'messages.root', @params.group unless @params.group == wildGroup  ## for title links
  ]
  data: ->
    group: @params.group
    message: @params.message
  fastRender: true

Router.route '/:group/settings',
  name: 'settings'
  fastRender: true

Router.route '/',
  name: 'frontpage'
  fastRender: true
