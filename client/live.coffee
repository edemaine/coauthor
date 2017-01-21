Template.live.onCreated ->
  setTitle 'Live Feed'

Template.live.helpers
  messages: ->
    Messages.find
      group: @group
      published: $ne: false
      deleted: false
    , liveMessagesLimit @limit
  valid: ->
    parseInt(@limit) >= 0

Template.live.events
  'change #limitInput': (e, t) ->
    Router.go 'live',
      group: @group
      limit: t.find('#limitInput').value

  'submit form': (e, t) ->
    e.preventDefault()

Template.readMessageNoHeader.onRendered ->
  @autorun ->
    Template.currentData()
    mathjax()

Template.readMessageNoHeader.helpers
  formatTitle: ->
    sanitizeHtml formatTitle @format, @title
  formatBody: ->
    sanitizeHtml formatBody @format, @body
