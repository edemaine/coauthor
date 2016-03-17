@routeGroupRoute = ->
  Iron.controller().getParams().group

@routeGroup = ->
  group = routeGroupRoute()
  if group == wildGroupRoute
    wildGroup
  else
    group

Template.registerHelper 'routeGroup', routeGroup

Template.registerHelper 'wildGroup', ->
  routeGroup() == wildGroup

Template.registerHelper 'groupData', ->
  Groups.findOne {name: routeGroup()}

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

Template.importButton.events
  'click .importButton': (e, t) ->
    e.preventDefault()
    e.stopPropagation()
    t.find('.importInput').click()
  'change .importInput': (e, t) ->
    importFiles t.data.group, e.target.files
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
    importFiles t.data.group, e.originalEvent.dataTransfer.files

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

Template.messageList.onRendered mathjax
Template.messageList.helpers
  topMessages: ->
    Messages.find
      group: @group
      root: null
    , sort:
      published: -1
  topMessageCount: ->
    pluralize(Messages.find
      group: @group
      root: null
    .count(), 'root message')
  messageLink: ->
    pathFor 'message',
      group: @group
      message: @_id

Template.messageShort.onRendered mathjax
Template.messageShort.helpers
  commentCount: ->
    pluralize @comments, 'comment'
