#Meteor.startup ->
#  ace.require 'ace/ext/spellcheck'

Template.registerHelper 'titleOrUntitled', ->
  titleOrUntitled @.title

Template.registerHelper 'isFile', ->
  @.format == 'file'

Template.registerHelper 'children', ->
  if @children
    children = Messages.find _id: $in: @children
                 .fetch()
    children = _.sortBy children, (child) => @children.indexOf child
    ## Use canSee to properly fake non-superuser mode.
    children = (child for child in children when canSee child)
    for child in children
      child.depth = (@depth ? 0) + 1
    children

Template.rootHeader.helpers
  root: ->
    if @root
      Messages.findOne @root

Template.registerHelper 'formatTitle', ->
  sanitizeHtml formatTitle @format, @title

Template.badMessage.helpers
  message: -> Router.current().params.message

orphans = (message) ->
  descendants = []
  Messages.find
    $or: [
      root: message
    , _id: message
    ]
  .forEach (descendant) ->
    descendants.push descendant.children... if descendant.children?
  Messages.find
    root: message
    _id: $nin: descendants

Template.message.helpers
  orphans: ->
    orphans @_id
  orphanCount: ->
    count = orphans(@_id).count()
    if count > 0
      pluralize orphans(@_id).count(), 'orphaned subthread'

Template.message.onCreated ->
  @autorun ->
    setTitle titleOrUntitled Template.currentData()?.title

Template.message.onRendered ->
  $('body').scrollspy
    target: 'nav.contents'
  $('nav.contents').affix
    offset: top: $('#top').outerHeight true
  $('.affix-top').height $(window).height() - $('#top').outerHeight true
  $(window).resize ->
    $('.affix-top').height $(window).height() - $('#top').outerHeight true
  $('nav.contents').on 'affixed.bs.affix', ->
    $('.affix').height $(window).height()
  $('nav.contents').on 'affixed-top.bs.affix', ->
    $('.affix-top').height $(window).height() - $('#top').outerHeight true
  $('[data-toggle="tooltip"]').tooltip()

  ## Give focus to first Title input, if there is one.
  titles = $('input.title')
  if titles.length
    titles[0].focus()

editing = (self) ->
  Meteor.user()? and Meteor.user().username in (self.editing ? [])

idle = 1000   ## one second

Template.registerHelper 'deletedClass', ->
  if @deleted
    'deleted'
  else if @published
    'published'
  else
    'unpublished'

submessageCount = 0

Template.submessage.onCreated ->
  @count = submessageCount++
  @keyboard = new ReactiveVar 'ace'
  @editing = new ReactiveVar null
  @history = new ReactiveVar null
  @raw = new ReactiveVar false
  ## @folded is normally true or false, but we use a special (falsey) null
  ## value to indicate that it could still be automatically folded if it's
  ## detected that that would be a better default.
  @folded = new ReactiveVar null
  @autorun =>
    return unless Template.currentData()?
    #@myid = Template.currentData()._id
    if editing Template.currentData()
      @editing.set Template.currentData()._id
    else
      @editing.set null
    #console.log 'automathjax'
    automathjax()

#Session.setDefault 'images', {}
images = {}
id2template = {}
scrollToLater = null

Template.submessage.onRendered ->
  ## Drag and drop support.
  id = @data._id
  group = @data.group
  focus = @$('.focusButton')
  focus.attr 'draggable', true
  focus.on 'dragstart', (e) ->
    url = "coauthor:#{id}"  ## xxx actually ignored!
    #url = pathFor 'message',
    #  group: group
    #  message: id
    e.dataTransfer.setData 'text/plain', url

  ## Fold deleted messages by default on initial load.
  @folded.set true if @data.deleted
  #@$.children('.panel').children('.panel-body').find('a[href|="/gridfs/fs/"]')
  #console.log @$ 'a[href|="/gridfs/fs/"]'
  template = @
  id2template[@data._id] = template
  scrollToMessage @data._id if scrollToLater == @data._id
  attachment = @data.format == 'file'
  #images = Session.get 'images'
  subimages = @images = []
  $(@firstNode).children('.panel-body').find('img[src^="/gridfs/fs/"]')
  .each ->
    id = url2file @.getAttribute('src')
    subimages.push id
    if id not of images
      images[id] =
        attachment: null
        count: 0
    if attachment
      images[id].attachment = template
    else
      images[id].count += 1
    if images[id].count > 0 and images[id].attachment? and images[id].attachment.folded.get() == null
      images[id].attachment.folded.set true
    #console.log images
  #Session.set 'images', images

scrollDelay = 750

@scrollToMessage = (id) ->
  if id of id2template
    template = id2template[id]
    $.scrollTo template.firstNode, scrollDelay,
      easing: 'swing'
      onAfter: ->
        $(template.find 'input.title').focus()
  else
    scrollToLater = id

Template.submessage.onDestroyed ->
  for id in @images
    if id of images
      images[id].count -= 1

historify = (x) -> () ->
  history = Template.instance().history.get()
  if history?
    history[x]
  else
    @[x]

tabindex = (i) -> 
  1 + 20 * Template.instance().count + parseInt(i ? 0)

Template.submessage.helpers
  tabindex: tabindex
  tabindex7: -> tabindex 7
  tabindex9: -> tabindex 9
  here: ->
    Router.current().route.getName() == 'message' and
    Router.current().params.message == @_id
  nothing: {}
  editingRV: -> Template.instance().editing.get()
  editingNR: -> Tracker.nonreactive -> Template.instance().editing.get()
  hideIfEditing: ->
    if Template.instance().editing.get()
      'hidden'
    else
      ''
  #myid: -> Tracker.nonreactive -> Template.instance().myid
  #editing: -> editing @
  config: ->
    ti = Tracker.nonreactive -> Template.instance()
    (editor) =>
      #console.log 'config', editor.getValue(), '.'
      ti.editor = editor
      editor.textInput.getElement().setAttribute 'tabindex', 1 + 20 * ti.count + 19
      #editor.meteorData = @  ## currently not needed, also dunno if works
      editor.$blockScrolling = Infinity
      #editor.on 'change', onChange
      editor.setTheme 'ace/theme/monokai'
      editor.getSession().setMode 'ace/mode/html'
      editor.setShowPrintMargin false
      editor.setBehavioursEnabled true
      editor.setShowFoldWidgets true
      editor.getSession().setUseWrapMode true
      #console.log "setting format to #{ti.data.format}"
      editor.getSession().setMode "ace/mode/#{ti.data.format}"
      #editor.setOption 'spellcheck', true

  keyboard: ->
    capitalize Template.instance().keyboard.get()
  activeKeyboard: (match) ->
    if Template.instance().keyboard.get() == match
      'active'
    else
      ''

  deleted: historify 'deleted'
  published: historify 'published'

  tex2jax: ->
    history = Template.instance().history.get() ? @
    if history.format in mathjaxFormats
      'tex2jax'
    else
      ''
  title: historify 'title'
  formatTitle: ->
    history = Template.instance().history.get() ? @
    title = history.title
    return title unless title
    if Template.instance().raw.get()
      "<CODE CLASS='raw'>#{_.escape title}</CODE>"
    else
      title = formatTitle history.format, title
      sanitized = sanitizeHtml title
      console.warn "Sanitized '#{title}' -> '#{sanitized}'" if sanitized != title
      sanitized
  formatBody: ->
    history = Template.instance().history.get() ? @
    body = history.body
    return body unless body
    if Template.instance().raw.get()
      "<PRE CLASS='raw'>#{_.escape body}</PRE>"
    else
      body = formatBody history.format, body
      sanitized = sanitizeHtml body
      console.warn "Sanitized '#{body}' -> '#{sanitized}'" if sanitized != body
      sanitized

  isFile: -> @format == 'file'
  canEdit: -> canEdit @_id
  canDelete: -> canDelete @_id
  canUndelete: -> canUndelete @_id
  canPublish: -> canPublish @_id
  canUnpublish: -> canUnpublish @_id
  canSuperdelete: -> canSuperdelete @_id
  canReply: -> canPost @group, @_id
  canAttach: -> canPost @group, @_id

  history: -> Template.instance().history.get()?
  forHistory: ->
    _id: @_id
    history: Template.instance().history

  folded: -> Template.instance().folded.get()
  raw: -> Template.instance().raw.get()

Template.registerHelper 'messagePanelClass', ->
  if @deleted
    'panel-danger message-deleted'
  else if @published
    'panel-primary message-published'
  else
    'panel-warning message-unpublished'

Template.registerHelper 'formatAuthors', ->
  a = for own author, date of @authors when author != @creator or date.getTime() != @created.getTime()
        "#{unescapeUser author} #{formatDate date, 'on '}"
  if a.length > 0
    ', edited by ' + a.join ", "

Template.submessage.events
  'click .foldButton': (e, t) ->
    e.preventDefault()
    e.stopPropagation()
    t.folded.set not t.folded.get()

  'click .rawButton': (e, t) ->
    e.preventDefault()
    e.stopPropagation()
    t.raw.set not t.raw.get()

  'click .editButton': (e, t) ->
    e.preventDefault()
    e.stopPropagation()
    message = t.data._id  #e.target.getAttribute 'data-message'
    if editing @
      Meteor.call 'messageEditStop', message
    else
      Meteor.call 'messageEditStart', message

  'click .publishButton': (e, t) ->
    e.preventDefault()
    e.stopPropagation()
    message = t.data._id
    ## Stop editing if we are publishing.
    if not @published and editing @
      Meteor.call 'messageEditStop', message
    Meteor.call 'messageUpdate', message,
      published: not @published

  'click .deleteButton': (e, t) ->
    e.preventDefault()
    e.stopPropagation()
    message = t.data._id
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
      format: format = e.target.getAttribute 'data-format'
    $(e.target).parent().dropdown 'toggle'
    #console.log "setting format to #{format}"
    Template.instance().editor.getSession().setMode "ace/mode/#{format}"

  'keyup input.title': (e, t) ->
    e.stopPropagation()
    message = t.data._id
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
          scrollToMessage result
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

  'click .replaceButton': (e, t) ->
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
      ,
        sort: ['updated']
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
          formatDate(diffs[i].updated) + '\n' + diffs[i].updators.join ', '
        else
          i
    @slider.setValue diffs.length-1
    #@slider.off 'change'
    @slider.on 'change', (e) =>
      @data.history.set diffs[e.newValue]
    @data.history.set diffs[diffs.length-1]

uploader = (template, button, input, callback) ->
  Template[template].events {
    "click .#{button}": (e, t) ->
      e.preventDefault()
      e.stopPropagation()
      t.find(".#{input}").click()
    "change .#{input}": (e, t) ->
      callback e.target.files, e, t
      e.target.value = ''
    "dragenter .#{button}": (e) ->
      e.preventDefault()
      e.stopPropagation()
    "dragover .#{button}": (e) ->
      e.preventDefault()
      e.stopPropagation()
    "drop .#{button}": (e, t) ->
      e.preventDefault()
      e.stopPropagation()
      callback e.originalEvent.dataTransfer.files, e, t
  }

attachFiles = (files, e, t) ->
  message = t.data._id
  group = t.data.group
  for file in files
    file.callback = (file2) ->
      Meteor.call 'messageNew', group, message, null,
        format: 'file'
        title: file2.fileName
        body: file2.uniqueIdentifier
    file.group = group
    Files.resumable.addFile file, e

uploader 'messageAttach', 'attachButton', 'attachInput', attachFiles

replaceFiles = (files, e, t) ->
  message = t.data._id
  group = t.data.group
  if files.length != 1
    console.error "Attempt to replace #{message} with #{files.length} files -- expected 1"
  else
    file = files[0]
    file.callback = (file2) ->
      Meteor.call 'messageUpdate', message,
        format: 'file'
        title: file2.fileName
        body: file2.uniqueIdentifier
    file.group = group
    Files.resumable.addFile file, e

uploader 'messageReplace', 'replaceButton', 'replaceInput', replaceFiles
