import {liveMessagesLimit} from '/lib/messages'

Template.live.onCreated ->
  @autorun ->
    setTitle 'Live Feed'

Template.live.helpers
  messages: ->
    Messages.find undeletedMessagesQuery(@group),
      liveMessagesLimit @limit
  valid: ->
    parseInt(@limit) >= 0

Template.live.events
  'change #limitInput': (e, t) ->
    Router.go 'live',
      GROUP: @group
      limit: t.find('#limitInput').value

  'submit form': (e, t) ->
    e.preventDefault()
