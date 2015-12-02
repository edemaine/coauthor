@routeGroup = ->
  group = Iron.controller().getParams().group
  if group == wildGroupRoute
    wildGroup
  else
    group

Template.registerHelper 'routeGroup', routeGroup

Template.registerHelper 'groupData', ->
  Groups.findOne {name: routeGroup()}

Template.registerHelper 'groups', ->
  Groups.find()

Template.registerHelper 'groupcount', ->
  Groups.find().count()

Template.registerHelper 'canImport', -> canImport @group

Template.postButtons.helpers
  disablePost: ->
    if canPost @group then '' else 'disabled'

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
    t.find('#importInput').click()
  'change #importInput': (e, t) ->
    importFiles t.data.group, t.find('#importInput').files
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

Template.messageList.onRendered mathjax
Template.messageList.helpers
  topMessages: ->
    Messages.find
      group: @group
      root: null
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
  title: ->
    if @title.trim().length == 0
      '<untitled>'
    else
      @title
  commentCount: ->
    pluralize @comments, 'comment'
