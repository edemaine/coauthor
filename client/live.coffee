Template.live.helpers
  messages: ->
    Messages.find
      group: @group
      published: $ne: false
      deleted: false
    ,
      sort: [['updated', 'desc']]
      limit: parseInt(@limit)
  valid: ->
    parseInt(@limit) >= 0

Template.live.events
  'change #limitInput': (e, t) ->
    Router.go 'live',
      group: @group
      limit: t.find('#limitInput').value

  'submit form': (e, t) ->
    e.preventDefault()

Template.readMessage.onRendered ->
  @autorun ->
    Template.currentData()
    mathjax()

Template.readMessage.helpers
  formatTitle: ->
    sanitizeHtml formatTitle @format, @title
  formatBody: ->
    sanitizeHtml formatBody @format, @body
