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
  @history = new ReactiveVar null
  @autorun =>
    return unless Template.currentData()?
    #@myid = Template.currentData()._id
    if editing Template.currentData()
      @editing.set Template.currentData()._id
    else
      @editing.set null
    #console.log 'automathjax'
    automathjax()

historify = (x) -> () ->
  history = Template.instance().history.get()
  if history?
    history[x]
  else
    @[x]

Template.submessage.helpers
  nothing: {}
  editingRV: -> Template.instance().editing.get()
  editingNR: -> Tracker.nonreactive -> Template.instance().editing.get()
  #myid: -> Tracker.nonreactive -> Template.instance().myid
  #editing: -> editing @
  children: ->
    if @children
      Messages.find _id: $in: @children
        .fetch()
  config: ->
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

  keyboard: ->
    capitalize Template.instance().keyboard.get()
  activeKeyboard: (match) ->
    if Template.instance().keyboard.get() == match
      'active'
    else
      ''

  title: historify 'title'
  deleted: historify 'deleted'
  published: historify 'published'

  tex2jax: ->
    history = Template.instance().history.get() ? @
    if history.format in mathjaxFormats
      ''
    else
      'tex2jax'
  body: ->
    history = Template.instance().history.get() ? @
    body = history.body
    return body unless body
    body = formatBody history.format, body
    sanitized = sanitizeHtml body
    if sanitized != body
      console.warn "Sanitized '#{body}' -> '#{sanitized}'"
    sanitized

  authors: ->
    a = for own author, date of @authors when author != @creator or date.getTime() != @created.getTime()
          "#{author} #{formatDate date}"
    if a.length > 0
      ', edited by ' + a.join ", "

  isFile: -> @format == 'file'
  canEdit: -> canEdit @_id
  canDelete: -> canEdit @_id
  canUndelete: -> canEdit @_id
  canPublish: -> canEdit @_id
  canUnpublish: -> canEdit @_id
  canSuperdelete: -> canSuperdelete @_id
  canReply: -> canPost @group, @_id
  canAttach: -> canPost @group, @_id

  history: -> Template.instance().history.get()?
  forHistory: ->
    _id: @_id
    history: Template.instance().history

Template.submessage.events
  'click .editButton': (e) ->
    e.preventDefault()
    e.stopPropagation()
    message = e.target.getAttribute 'data-message'
    if editing @
      Meteor.call 'messageEditStop', message
    else
      Meteor.call 'messageEditStart', message

  'click .publishButton': (e) ->
    e.preventDefault()
    e.stopPropagation()
    message = e.target.getAttribute 'data-message'
    ## Stop editing if we are publishing.
    if not @published and editing @
      Meteor.call 'messageEditStop', message
    Meteor.call 'messageUpdate', message,
      published: not @published

  'click .deleteButton': (e) ->
    e.preventDefault()
    e.stopPropagation()
    message = e.target.getAttribute 'data-message'
    ## Stop editing if we are deleting.
    if not @deleted and editing @
      Meteor.call 'messageEditStop', message
    Meteor.call 'messageUpdate', message,
      deleted: not @deleted

  'click .editorKeyboard': (e, t) ->
    e.preventDefault()
    e.stopPropagation()
    t.keyboard.set kb = e.target.getAttribute 'data-keyboard'
    t.editor.setKeyboardHandler if kb == 'ace' then '' else 'ace/keyboard/' + kb
    $(e.target).parent().dropdown 'toggle'

  'click .editorFormat': (e, t) ->
    e.preventDefault()
    e.stopPropagation()
    Meteor.call 'messageUpdate', t.data._id,
      format: e.target.getAttribute 'data-format'
    $(e.target).parent().dropdown 'toggle'

  'keyup input.title': (e, t) ->
    message = e.target.getAttribute 'data-message'
    Meteor.clearTimeout t.timer
    t.timer = Meteor.setTimeout ->
      Meteor.call 'messageUpdate', message,
        title: e.target.value
    , idle

  'click .replyButton': (e, t) ->
    e.preventDefault()
    e.stopPropagation()
    message = @_id
    if canPost @group, @_id
      Meteor.call 'messageNew', @group, @_id, (error, result) ->
        if error
          console.error error
        else if result
          Meteor.call 'messageEditStart', result
          #Router.go 'message', {group: group, message: result}
        else
          console.error "messageNew did not return problem -- not authorized?"

  'click .historyButton': (e, t) ->
    e.preventDefault()
    e.stopPropagation()
    if t.history.get()?
      t.history.set null
    else
      t.history.set _.clone @

  'click .superdeleteButton': (e) ->
    e.preventDefault()
    e.stopPropagation()
    Modal.show 'superdelete', @

  'click .attachButton': (e, t) ->
    e.preventDefault()
    e.stopPropagation()
    

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

Template.messageHistory.onCreated ->
  @diffsub = @subscribe 'messages.diff', @data._id

Template.messageHistory.onRendered ->
  @autorun =>
    diffs = MessagesDiff.find
        id: @data._id
      .fetch()
    return if diffs.length < 2  ## don't show a zero-length slider
    ## Accumulate diffs
    for diff, i in diffs
      if i >= 0
        for own key, value of diffs[i-1]
          unless key of diff
            diff[key] = value
    @slider?.destroy()
    @slider = new Slider @$('input')[0],
      #min: 0                 ## min and max not needed when using ticks
      #max: diffs.length-1
      #value: diffs.length-1  ## doesn't update, unlike setValue method below
      ticks: [0...diffs.length]
      ticks_snap_bounds: 999999999
      tooltip: 'always'
      tooltip_position: 'bottom'
      formatter: (i) ->
        if i of diffs
          formatDate(diffs[i].updated, '') + '\n' + diffs[i].updators.join ', '
        else
          i
    @slider.setValue diffs.length-1
    #@slider.off 'change'
    @slider.on 'change', (e) =>
      @data.history.set diffs[e.newValue]
    @data.history.set diffs[diffs.length-1]

attachFiles = (files, e, t) ->
  message = t.data._id
  group = t.data.group
  for file in files
    file.callback = (file2) ->
      Meteor.call 'messageNew', group, message,
        (error, result) ->
          if error?
            throw error
          else
            Meteor.call 'messageUpdate', result,
              format: 'file'
              title: file2.fileName
              body: file2.uniqueIdentifier
    file.group = group
    Files.resumable.addFile file, e

Template.messageAttach.events
  'click .attachButton': (e, t) ->
    e.preventDefault()
    e.stopPropagation()
    t.find('.attachInput').click()
  'change .attachInput': (e, t) ->
    attachFiles e.target.files, e, t
    e.target.value = ''
  'dragenter .attachButton': (e) ->
    e.preventDefault()
    e.stopPropagation()
  'dragover .attachButton': (e) ->
    e.preventDefault()
    e.stopPropagation()
  'drop .attachButton': (e, t) ->
    e.preventDefault()
    e.stopPropagation()
    attachFiles e.originalEvent.dataTransfer.files, e, t

Template.registerHelper 'uploading', ->
  value for own key, value of Session.get 'uploading'
