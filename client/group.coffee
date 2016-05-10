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

@linkToSort = (sort) ->
  if sort.reverse
    route = 'group.sorted.reverse'
  else
    route = 'group.sorted.forward'
  pathFor route,
    group: routeGroup()
    sortBy: sort.key

Template.postButtons.helpers
  sortBy: ->
    capitalize sortBy().key
  sortReverse: ->
    sortBy().reverse
  activeSort: ->
    if sortBy().key == @key
      'active'
    else
      ''
  capitalizedKey: ->
    capitalize @key
  sortKeys: ->
    key: key for key in sortKeys
  linkToSort: ->
    linkToSort
      key: @key
      reverse: sortBy().reverse
  linkToReverse: ->
    linkToSort
      key: sortBy().key
      reverse: not sortBy().reverse

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
  members: ->
    members =
      for member in groupMembers @group
        linkToAuthor @group, member
    if members.length > 0
      members.join(', ')
    else
      '(none)'

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

Template.messageList.onRendered ->
  mathjax()
  $('[data-toggle="tooltip"]').tooltip()

Template.messageList.helpers
  linkToSort: (key) ->
    if key == sortBy().key
      linkToSort
        key: key
        reverse: not sortBy().reverse
    else
      linkToSort
        key: key
        reverse: key in ['published', 'updated', 'posts', 'subscribe']  ## default reverse
  sortingBy: (key) ->
    sortBy().key == key
  sortingGlyph: ->
    if sortBy().reverse
      'glyphicon-sort-by-alphabet-alt'
    else
      'glyphicon-sort-by-alphabet'
  topMessages: ->
    query =
      group: @group
      root: null
    sort = sortBy()
    mongosort = [[sort.key, if sort.reverse then 'desc' else 'asc']]
    msgs = Messages.find query, sort: mongosort
    if sort.key in ['title', 'posts', 'updated', 'subscribe']
      switch sort.key
        when 'title'
          key = (msg) -> titleSort msg.title
        when 'posts'
          key = (msg) -> submessageCount msg
        when 'updated'
          key = (msg) -> lastSubmessageUpdate(msg).getTime()
        when 'subscribe'
          key = (msg) -> subscribedToMessage msg._id
      msgs = msgs.fetch()
      msgs = _.sortBy msgs, key
      msgs.reverse() if sort.reverse
    msgs

Template.messageShort.onRendered ->
  mathjax()

@submessageCount = (message) ->
  Messages.find
    root: message._id
  .count()

@lastSubmessageUpdate = (message) ->
  updated = message.updated
  Messages.find
    root: message._id
  .forEach (submessage) ->
    updated = dateMax updated, submessage.updated
  updated

Template.messageShort.helpers
  formatTitle: ->
    sanitizeHtml formatTitle @format, titleOrUntitled @title
  messageLink: ->
    pathFor 'message',
      group: @group
      message: @_id
  submessageCount: ->
    submessageCount @
  zeroClass: ->
    if 0 == Messages.find(
              root: @_id
            ).count()
      'badge-zero'
    else
      ''
  lastSubmessageUpdate: ->
    formatDate lastSubmessageUpdate @
  subscribed: ->
    subscribedToMessage @_id

Template.messageShort.events
  'click button.subscribe': (e, t) ->
    e.preventDefault()
    e.stopPropagation()
    if subscribedToMessage @_id
      Meteor.users.update Meteor.userId(),
        $push: 'profile.notifications.unsubscribed': @_id
        $pop: 'profile.notifications.subscribed': @_id
    else
      Meteor.users.update Meteor.userId(),
        $push: 'profile.notifications.subscribed': @_id
        $pop: 'profile.notifications.unsubscribed': @_id
