###
IronRouter routes

When adding a new route here, consider adding it to the `linkToRoutes`
in ../client/layout.coffee, so that changing the group will preserve
the details of the route.
###

#@Subscribe = Meteor
@Subscribe = new SubsManager

Router.configure
  layoutTemplate: 'layout'
  loadingTemplate: 'loading'
  subscriptions: -> [
    Subscribe.subscribe 'groups'
  ]

Router.route '/:GROUP/m/:message',
  #Session.set 'group', Groups.findOne
  #  name: @params.GROUP
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
    unless @params.GROUP == wildGroup
      subs.push ...[
        Subscribe.subscribe 'messages.root', @params.GROUP
        Subscribe.subscribe 'groups.members', @params.GROUP
        Subscribe.subscribe 'tags', @params.GROUP
        Subscribe.subscribe 'files', @params.GROUP
      ]
    subs
  data: ->
    _id: @params.message
  #dataNotFoundTemplate: 'NotFound'
  action: ->
    if @params.GROUP == wildGroup
      if @ready()
        msg = findMessage @params.message
        if msg?.group
          return @redirect 'message',
            GROUP: msg.group
            message: @params.message
          ,
            replaceState: true
            hash: @params.hash
            query: @params.query
      @render 'messageBad'
    else
      @render()
  fastRender: true

# Want to write /:GROUP/:sortBy?, but this would match everything
for sortChar in ['', '+', '-']
  Router.route '/:GROUP' + (sortChar and "/#{sortChar}:sortBy"),
    name: 'group' + sortChar
    template: 'group'
    subscriptions: -> [
      Subscribe.subscribe 'messages.root', @params.GROUP
      #Subscribe.subscribe 'emoji.root', @params.GROUP
      Subscribe.subscribe 'groups.members', @params.GROUP
      Subscribe.subscribe 'tags', @params.GROUP
    ]
    data: ->
      group: @params.GROUP
    fastRender: true

defaultSince = '1 hour'

Router.route '/:GROUP/since/:since?',
  name: 'since'
  subscriptions: -> [
    Subscribe.subscribe 'messages.since', @params.GROUP, (@params.since ? defaultSince)
    Subscribe.subscribe 'messages.root', @params.GROUP unless @params.GROUP == wildGroup
    Subscribe.subscribe 'groups.members', @params.GROUP
    Subscribe.subscribe 'tags', @params.GROUP
    Subscribe.subscribe 'files', @params.GROUP
  ]
  data: ->
    group: @params.GROUP
    since: @params.since ? defaultSince
  fastRender: true

defaultLiveLimit = 10

Router.route '/:GROUP/live/:limit?',
  name: 'live'
  subscriptions: -> [
    Subscribe.subscribe 'messages.live', @params.GROUP, (@params.limit ? defaultLiveLimit)
    Subscribe.subscribe 'messages.root', @params.GROUP unless @params.GROUP == wildGroup
    Subscribe.subscribe 'groups.members', @params.GROUP
    Subscribe.subscribe 'tags', @params.GROUP
    Subscribe.subscribe 'files', @params.GROUP
  ]
  data: ->
    group: @params.GROUP
    limit: @params.limit ? defaultLiveLimit
  fastRender: true

Router.route '/:GROUP/author/:author',
  name: 'author'
  subscriptions: -> [
    Subscribe.subscribe 'messages.author', @params.GROUP, @params.author
    Subscribe.subscribe 'messages.root', @params.GROUP unless @params.GROUP == wildGroup
    Subscribe.subscribe 'groups.members', @params.GROUP
    Subscribe.subscribe 'tags', @params.GROUP
    Subscribe.subscribe 'files', @params.GROUP
  ]
  data: ->
    group: @params.GROUP
    author: @params.author
  fastRender: true

#Router.route '/:GROUP/tag/:tag',
#  name: 'tag'
#  subscriptions: -> [
#    Subscribe.subscribe 'messages.root', @params.GROUP
#    Subscribe.subscribe 'messages.tag', @params.GROUP, @params.tag
#    Subscribe.subscribe 'groups.members', @params.GROUP
#    Subscribe.subscribe 'files', @params.GROUP
#  ]
#  data: ->
#    group: @params.GROUP
#    tag: @params.tag
#  fastRender: true

Router.route '/:GROUP/stats/:username?',
  name: 'stats'
  template: 'stats'
  subscriptions: -> [
    #Subscribe.subscribe 'messages.author', @params.GROUP, @params.username if @params.username
    Subscribe.subscribe 'messages.all', @params.GROUP
    Subscribe.subscribe 'groups.members', @params.GROUP
  ]
  data: ->
    group: @params.GROUP
    username: @params.username
    unit: @params.query.unit
  fastRender: true

Router.route '/:GROUP/search/:search([^]*)',
  name: 'search'
  subscriptions: -> [
    Subscribe.subscribe 'messages.search', @params.GROUP, @params.search
    Subscribe.subscribe 'messages.root', @params.GROUP unless @params.GROUP == wildGroup
    Subscribe.subscribe 'groups.members', @params.GROUP
    Subscribe.subscribe 'tags', @params.GROUP
    Subscribe.subscribe 'files', @params.GROUP
  ]
  data: ->
    group: @params.GROUP
    search: @params.search
  fastRender: true

Router.route '/:GROUP/users',
  name: 'users'
  subscriptions: -> [
    Subscribe.subscribe 'users', @params.GROUP
    Subscribe.subscribe 'messages.root', @params.GROUP unless @params.GROUP == wildGroup  ## for title links
  ]
  data: ->
    group: @params.GROUP
  fastRender: true

Router.route '/:GROUP/users/:message',
  name: 'users.message'
  template: 'users'
  subscriptions: -> [
    Subscribe.subscribe 'users', @params.GROUP
    Subscribe.subscribe 'messages.root', @params.GROUP unless @params.GROUP == wildGroup  ## for title links
  ]
  data: ->
    group: @params.GROUP
    message: @params.message
  fastRender: true

Router.route '/:GROUP/settings',
  name: 'settings'
  fastRender: true

Router.route '/',
  name: 'frontpage'
  fastRender: true
