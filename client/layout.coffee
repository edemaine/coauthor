Template.registerHelper 'uploading', ->
  value for own key, value of Session.get 'uploading'

linkToRoutes =
  since: true
  live: true
  author: true
  tag: true
  stats: true
  users: true
  settings: true
  search: true

Template.layout.onRendered ->
  ## Create Google font without italic definition to get slanted (fake-italic)
  ## version for \textsl support.
  ## See https://stackoverflow.com/questions/11042330/force-the-browser-to-use-faux-italic-oblique-and-not-the-real-italic
  for child in document.head.children
    if child.tagName == 'LINK' and child.href.match /fonts.googleapis.com/
      rules = (rule for rule in child.sheet.cssRules)  ## copy before modifying
      for rule in rules
        if rule.style.fontStyle == 'normal'  ## skip italic definitions
          child.sheet.insertRule (
            rule.cssText.replace /font-family:\s*/i, '$&Slant'
          ), child.sheet.cssRules.length  ## append
      break

Template.layout.helpers
  themeGlobal: -> themeGlobal()
  activeGroup: ->
    data = Template.parentData()
    if routeGroup() == @name
      'active'
    else
      ''
  inUsers: ->
    (Router.current().route?.getName() ? '')[...5] == 'users'
  linkToUsers: ->
    if message = routeMessage()
      pathFor 'users.message',
        group: routeGroupOrWild()
        message: message2root message
    else
      pathFor 'users', group: routeGroupOrWild()
  linkToUsersExit: ->
    if message = routeMessage()
      pathFor 'message',
        group: routeGroupOrWild()
        message: message
    else
      pathFor 'group', group: routeGroupOrWild()
  linkToGroup: ->
    router = Router.current()
    route = Router.current().route?.getName()
    if linkToRoutes[route]
      pathFor route,
        _.extend _.omit(router.params, 'length'),
          group: @name
    else
      pathFor 'group',
        group: @name
  creditsWide: ->
    Router.current().route?.getName() != 'message'

Template.registerHelper 'couldSuper', ->
  canSuper routeGroupOrWild(), false

Template.registerHelper 'super', ->
  Session.get 'super'

Template.registerHelper 'globalSuper', ->
  Session.get('super') and canSuper wildGroup

Template.layout.events
  'click .superButton': (e) ->
    e.preventDefault()
    e.stopPropagation()
    Session.set 'super', not Session.get 'super'
  'submit .searchForm': (e, t) ->
    e.preventDefault()
    e.stopPropagation()
    Router.go 'search',
      group: routeGroupOrWild()
      search: t.find('.searchText').value
      0: '*'
      1: '*'
      2: '*'
      3: '*'
      4: '*'
      5: '*'
      6: '*'
      7: '*'
      8: '*'
      9: '*'
  'dragstart a.author': (e) ->
    username = e.target.getAttribute 'data-username'
    dataTransfer = e.originalEvent.dataTransfer
    dataTransfer.effectAllowed = 'linkCopy'
    dataTransfer.setData 'text/plain', e.target.getAttribute 'href'
    dataTransfer.setData 'application/coauthor-username', username
  'dragenter a.author': (e) ->
    e.preventDefault()
    e.stopPropagation()
  'dragover a.author': (e) ->
    e.preventDefault()
    e.stopPropagation()
