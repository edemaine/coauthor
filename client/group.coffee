@routeGroupRoute = ->
  Router.current().params.group

@routeGroup = ->
  group = routeGroupRoute()
  if group == wildGroupRoute
    wildGroup
  else
    group

@routeGroupOrWild = ->
  routeGroup() ? wildGroup

Template.registerHelper 'routeGroup', routeGroup

Template.registerHelper 'wildGroup', ->
  routeGroup() == wildGroup

@groupData = ->
  Groups.findOne
    name: routeGroup()

Template.registerHelper 'groupData', groupData

@defaultSort =
  key: 'published'
  reverse: true

@sortBy = ->
  if Router.current().params.sortBy in sortKeys
    key: Router.current().params.sortBy
    reverse: Router.current().route.getName()[-7..] == 'reverse'
  else if groupData().defaultSort?
    groupData().defaultSort
  else
    defaultSort

Template.postButtons.helpers
  'sortBy': ->
    sortBy().key
  'sortReverse': ->
    sortBy().reverse
  'activeSort': ->
    if sortBy().key == @key
      'active'
    else
      ''
  'sortKeys': ->
    key: key for key in sortKeys
  'linkToSort': ->
    if sortBy().reverse
      route = 'group.sorted.reverse'
    else
      route = 'group.sorted.forward'
    pathFor route,
      group: routeGroup()
      sortBy: @key
  'linkToReverse': ->
    unless sortBy().reverse
      route = 'group.sorted.reverse'
    else
      route = 'group.sorted.forward'
    pathFor route,
      group: routeGroup()
      sortBy: sortBy().key

Template.registerHelper 'groups', ->
  Groups.find()

Template.registerHelper 'groupcount', ->
  Groups.find().count()

Template.registerHelper 'admin', -> canAdmin @group

Template.registerHelper 'canImport', -> canImport @group

Template.registerHelper 'canSee', -> canSee @

Template.group.onCreated ->
  @autorun ->
    setTitle()

Template.group.helpers
  topMessageCount: ->
    pluralize(Messages.find
      group: @group
      root: null
    .count(), 'root message')

Template.postButtons.helpers
  disableClass: ->
    if canPost @group
      ''
    else
      'disabled'
  disableTitle: ->
    if canPost @group
      ''
    else if Meteor.userId()?
      'You do not have permission to post a message in this group.'
    else
      'You need to be logged in to post a message.'

Template.postButtons.onRendered ->
  $('[data-toggle="tooltip"]').tooltip()

Template.postButtons.events
  'click .sortSetDefault': (e) ->
    e.stopPropagation()
    console.log "Setting default sort for #{routeGroup()} to #{if sortBy().reverse then '-' else '+'}#{sortBy().key}"
    Meteor.call 'groupDefaultSort', routeGroup(), sortBy()

  'click .postButton': (e) ->
    e.preventDefault()
    e.stopPropagation()
    type = e.target.id
    #$("#poseButton").addClass 'disabled'
    if canPost @group
      group = @group  ## for closure
      Meteor.call 'messageNew', group, (error, result) ->
        #$("#poseButton").removeClass 'disabled'
        if error
          console.error error
        else if result
          Meteor.call 'messageEditStart', result
          Router.go 'message', {group: group, message: result}
        else
          console.error "messageNew did not return problem -- not authorized?"

Template.importButtons.events
  'click .importButton': (e, t) ->
    e.preventDefault()
    e.stopPropagation()
    t.find(".importInput[data-format='#{e.target.getAttribute('data-format')}']").click()
  'change .importInput': (e, t) ->
    importFiles e.target.getAttribute('data-format'), t.data.group, e.target.files
    e.target.value = ''
  'dragenter .importButton': (e) ->
    e.preventDefault()
    e.stopPropagation()
  'dragover .importButton': (e) ->
    e.preventDefault()
    e.stopPropagation()
  'drop .importButton': (e, t) ->
    e.preventDefault()
    e.stopPropagation()
    importFiles e.target.getAttribute('data-format'), t.data.group, e.originalEvent.dataTransfer.files

  'click .superdeleteImportButton': (e, t) ->
    e.preventDefault()
    e.stopPropagation()
    Modal.show 'superdeleteImport', @

Template.superdeleteImport.events
  'click .shallowSuperdeleteButton': (e, t) ->
    e.preventDefault()
    e.stopPropagation()
    Modal.hide()
    count = 0
    Messages.find
      group: t.data.group
      imported: $ne: null
    .forEach (msg) ->
      count += 1
      console.log 'Superdeleting', msg._id
      Meteor.call 'messageSuperdelete', msg._id
    console.log 'Superdeleted', count, 'imported messages'
  'click .cancelButton': (e) ->
    e.preventDefault()
    e.stopPropagation()
    Modal.hide()

titleDigits = 10
titleSort = (title) ->
  title = title.title if title.title?
  title.toLowerCase().replace /\d+/, (n) -> s.lpad n, titleDigits, '0'

Template.messageList.onRendered ->
  mathjax()
  $('[data-toggle="tooltip"]').tooltip()

Template.messageList.helpers
  topMessages: ->
    query =
      group: @group
      root: null
    sort = sortBy()
    sortdict = {}
    sortdict[sort.key] = if sort.reverse then -1 else 1
    msgs = Messages.find query, sort: sortdict
    if sort.key == 'title'
      msgs = msgs.fetch()
      msgs.sort (x, y) ->
        if titleSort(x.title) < titleSort(y.title)
          -1
        else if titleSort(x.title) > titleSort(y.title)
          1
        else
          0
      msgs.reverse() if sort.reverse
    msgs

Template.messageShort.onRendered ->
  mathjax()

Template.messageShort.helpers
  formatTitle: ->
    sanitizeHtml formatTitle @format, titleOrUntitled @title
  messageLink: ->
    pathFor 'message',
      group: @group
      message: @_id
  submessageCount: ->
    Messages.find
      root: @_id
    .count()
  zeroClass: ->
    if 0 == Messages.find(
              root: @_id
            ).count()
      'badge-zero'
    else
      ''

