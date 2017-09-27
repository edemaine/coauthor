Template.live.onCreated ->
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
      group: @group
      limit: t.find('#limitInput').value

  'submit form': (e, t) ->
    e.preventDefault()
