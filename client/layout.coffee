import React from 'react'

linkToRoutes =
  since: true
  live: true
  author: true
  tag: true
  stats: true
  users: true
  settings: true
  search: true

# IronRouter trims leading and trailing /s and combines
# consecutive /s, so quote them
protectSlash = (params) ->
  params.search = params.search.replace /\//g, '%SLASH%' if params.search?
  params
resolveSlash = (url) ->
  url?.replace /%25SLASH%25/g, '%2F'

Template.layout.onRendered ->
  ## In case Coauthor is mounted within a subdirectory, update favicon paths
  document.getElementById('iconIco').href = Meteor.absoluteUrl 'favicon.ico'
  document.getElementById('iconPNG').href = Meteor.absoluteUrl 'favicon32.png'

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
  activeGroup: ->
    if routeGroup() == @name
      'active'
    else
      ''
  inUsers: ->
    (Router.current().route?.getName() ? '')[...5] == 'users'
  linkToUsers: ->
    if (message = routeMessage())
      pathFor 'users.message',
        GROUP: routeGroupOrWild()
        message: message2root message
    else
      pathFor 'users', GROUP: routeGroupOrWild()
  linkToUsersExit: ->
    if (message = routeMessage())
      pathFor 'message',
        GROUP: routeGroupOrWild()
        message: message
    else
      pathFor 'group', GROUP: routeGroupOrWild()
  linkToSettings: ->
    pathFor 'settings', GROUP: routeGroupOrWild()
  linkToGroup: ->
    router = Router.current()
    route = Router.current().route?.getName()
    if linkToRoutes[route]
      resolveSlash pathFor route,
        protectSlash _.extend _.omit(router.params, 'length'),
          GROUP: @name
    else
      pathFor 'group',
        GROUP: @name
  searchPlaceholder: ->
    if routeGroupOrWild() == wildGroup
      'Search globally'
    else if routeMessage()
      'Search in thread'
    else
      'Search in group'
  creditsWide: ->
    Router.current().route?.getName() != 'message'

export Credits = React.memo ->
  <p className="credits clearfix">
    <img src={favicon()}/>
    {' '}
    <b>Coauthor</b> written by <a href="http://erikdemaine.org">Erik Demaine</a>, with help from many others.
    <span className="space"/>
    <span className="btn-group btn-group-sm pull-right">
      <a className="btn btn-default" href="https://github.com/edemaine/coauthor/#coauthor">Documentation</a>
      <a className="btn btn-default" href="https://github.com/edemaine/coauthor/blob/main/CHANGELOG.md">Changelog</a>
      <a className="btn btn-default" href="https://github.com/edemaine/coauthor/issues/">Suggestions/Issues</a>
      <a className="btn btn-default" href="https://github.com/edemaine/coauthor/">Source Code</a>
    </span>
  </p>
Credits.displayName = 'Credits'

Template.registerHelper 'favicon', favicon = ->
  Meteor.absoluteUrl 'favicon32.png'

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
    search = t.find('.searchText').value
    unless search  # empty query = clear search -> go to group page
      if routeGroupOrWild() == wildGroup
        Router.go 'frontpage'
      else
        Router.go 'group',
          GROUP: routeGroup()
    else
      if (message = routeMessage())
        search = "(#{search})" if /\|/.test search
        search = "#{search} root:#{message2root message}"
      Router.go resolveSlash Router.path 'search', protectSlash
        GROUP: routeGroupOrWild()
        search: search
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

Template.footer.helpers
  showFooter: ->
    return true for own key of Session.get 'uploading' # eslint-disable-line coffee/no-unused-vars
    return true if Session.get 'migrate'

Template.migrate.helpers
  migrate: -> Session.get 'migrate'

Template.uploadProgress.helpers
  uploading: ->
    value for own key, value of Session.get 'uploading'
