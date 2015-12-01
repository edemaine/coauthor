Template.badMessage.helpers
  'message': -> Iron.controller().getParams().message

Template.message.onRendered ->
  ## Start edit mode (if not already there) and select title if #edit is in
  ## the URL (as caused by creating a brand new message from the group).
  ## This is a bit hacky, via jquery, because we don't have an easy way to
  ## get to the (first) child submessage template...
  if window.location.hash == '#edit'
    button = $('.editButton').first()
    if button.text() == 'Edit'
      button.click()
    count = 50  ## give up after 5 seconds
    focusTitle = ->
      input = $('input.title')
      if input.length == 0
        count -= 1
        if count < 0
          Meteor.setTimeout focusTitle, 100
      else
        input[0].focus()
    Meteor.setTimeout focusTitle, 100

editing = (self) ->
  Meteor.user()? and Meteor.user().username in (self.editing ? [])

idle = 1000   ## one second

Template.submessage.onCreated ->
  @keyboard = new ReactiveVar 'ace'
  @editing = new ReactiveVar null
  @autorun =>
    return unless Template.currentData()?
    #@myid = Template.currentData()._id
    if editing Template.currentData()
      @editing.set Template.currentData()._id
    else
      @editing.set null
    #console.log 'automathjax'
    automathjax()

Template.submessage.helpers
  'nothing': {}
  'editingRV': -> Template.instance().editing.get()
  'editingNR': -> Tracker.nonreactive -> Template.instance().editing.get()
  #'myid': -> Tracker.nonreactive -> Template.instance().myid
  #'editing': ->
  #  editing @
  'children': ->
    if @.children
      Messages.find _id: $in: @.children
        .fetch()
  'config': ->
    ti = Tracker.nonreactive -> Template.instance()
    (editor) ->
      #console.log 'config', editor.getValue(), '.'
      ti.editor = editor
      #editor.meteorData = this  ## currently not needed, also dunno if works
      editor.$blockScrolling = Infinity
      #editor.on 'change', onChange
      editor.setTheme 'ace/theme/monokai'
      editor.getSession().setMode 'ace/mode/html'
      editor.setShowPrintMargin false
      editor.setBehavioursEnabled true
      editor.setShowFoldWidgets true
      editor.getSession().setUseWrapMode true

  'keyboard': ->
    capitalize Template.instance().keyboard.get()
  'activeKeyboard': (match) ->
    if Template.instance().keyboard.get() == match
      'active'
    else
      ''

  'format': ->
    capitalize @format
  'activeFormat': (match) ->
    if @format == match
      'active'
    else
      ''

  'body': ->
    return @body unless @body?
    body = @body
    switch @format
      when 'markdown'
        body = marked body
    sanitized = sanitizeHtml body
    if sanitized != body
      console.warn "Sanitized '#{body}' -> '#{sanitized}'"
    sanitized

  'authors': ->
    a = for own author, date of @authors when author != @creator or date.getTime() != @created.getTime()
          "#{author} #{formatDate date}"
    if a.length > 0
      ', edited by ' + a.join ", "

  'canEdit': -> canEdit @_id
  'canDelete': -> canEdit @_id
  'canUndelete': -> canEdit @_id
  'canPublish': -> canEdit @_id
  'canUnpublish': -> canEdit @_id
  'canSuperdelete': -> canSuperdelete @_id
  'canReply': -> canPost @group, @_id

Template.submessage.events
  'click .editButton': (e) ->
    e.preventDefault()
    message = e.target.getAttribute 'data-message'
    if editing @
      Meteor.call 'messageEditStop', message
    else
      Meteor.call 'messageEditStart', message

  'click .publishButton': (e) ->
    e.preventDefault()
    message = e.target.getAttribute 'data-message'
    ## Stop editing if we are publishing.
    if not @published and editing @
      Meteor.call 'messageEditStop', message
    Meteor.call 'messageUpdate', message,
      published: not @published

  'click .deleteButton': (e) ->
    e.preventDefault()
    message = e.target.getAttribute 'data-message'
    ## Stop editing if we are deleting.
    if not @deleted and editing @
      Meteor.call 'messageEditStop', message
    Meteor.call 'messageUpdate', message,
      deleted: not @deleted

  'click .editorKeyboard': (e, t) ->
    e.preventDefault()
    t.keyboard.set kb = e.target.getAttribute 'data-keyboard'
    t.editor.setKeyboardHandler if kb == 'ace' then '' else 'ace/keyboard/' + kb

  'click .editorFormat': (e, t) ->
    e.preventDefault()
    Meteor.call 'messageUpdate', t.data._id,
      format: e.target.getAttribute 'data-format'

  'keyup input.title': (e, t) ->
    message = e.target.getAttribute 'data-message'
    Meteor.clearTimeout t.timer
    t.timer = Meteor.setTimeout ->
      Meteor.call 'messageUpdate', message,
        title: e.target.value
    , idle

  'click .replyButton': (e) ->
    e.preventDefault()
    e.stopPropagation()
    message = e.target.getAttribute 'data-message'
    if canPost @group, message
      group = @group  ## for closure
      Meteor.call 'messageNew', group, message, (error, result) ->
        if error
          console.error error
        else if result
          Meteor.call 'messageEditStart', result
          #Router.go 'message', {group: group, message: result}
        else
          console.error "messageNew did not return problem -- not authorized?"

  'click .superdeleteButton': (e) ->
    e.preventDefault()
    e.stopPropagation()
    Modal.show 'superdelete', @

Template.superdelete.events
  'click .shallowSuperdeleteButton': (e, t) ->
    e.preventDefault()
    e.stopPropagation()
    Modal.hide()
    Meteor.call 'messageSuperdelete', t.data._id
  'click .deepSuperdeleteButton': (e, t) ->
    e.preventDefault()
    e.stopPropagation()
    Modal.hide()
    recurse = (message) ->
      msg = Messages.findOne message
      for child in msg.children
        recurse child
      Meteor.call 'messageSuperdelete', message
    recurse t.data._id
  'click .cancelButton': (e) ->
    e.preventDefault()
    e.stopPropagation()
    Modal.hide()