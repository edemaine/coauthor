sharejsEditor = 'cm'  ## 'ace' or 'cm'; also change template used in message.jade

switch sharejsEditor
  when 'cm'
    editorMode = (editor, format) ->
      editor.setOption 'backdrop',
        switch format
          when 'markdown'
            'gfm-math'  ## Git-flavored Markdown, plus our math extensions
          when 'html'
            'html-math'
          when 'latex'
            'stex'
          else
            format
      editor.setOption 'mode', 'spell-checker'
    editorKeyboard = (editor, keyboard) ->
      editor.setOption 'keyMap',
        switch keyboard
          when 'normal'
            'default'
          else
            keyboard
  when 'ace'
    editorMode = (editor, format) ->
      editor.getSession().setMode "ace/mode/#{format}"
    editorKeyboard = (editor, keyboard) ->
      editor.setKeyboardHandler(
        switch keyboard
          when 'normal'
            ''
          else
            "ace/keyboard/#{keyboard}"
      )

dropdownToggle = (e) ->
  #$(e.target).parent().dropdown 'toggle'
  $(e.target).parents('.dropdown-menu').first().parent().find('.dropdown-toggle').dropdown 'toggle'

#Template.registerHelper 'titleOrUntitled', ->
#  titleOrUntitled @

Template.registerHelper 'children', ->
  return @children unless @children
  children = Messages.find _id: $in: @children
               .fetch()
  children = _.sortBy children, (child) => @children.indexOf child._id
  ## Use canSee to properly fake non-superuser mode.
  children = (child for child in children when canSee child)
  for child, index in children
    child.depth = (@depth ? 0) + 1
    child.index = index
  children

Template.registerHelper 'tags', ->
  sortTags @tags

Template.registerHelper 'linkToTag', ->
  pathFor 'tag',
    group: Template.parentData().group
    tag: @key

Template.rootHeader.helpers
  root: ->
    if @root
      Messages.findOne @root

Template.registerHelper 'formatTitle', ->
  formatTitleOrFilename @, false

Template.registerHelper 'formatTitleOrUntitled', ->
  formatTitleOrFilename @, true

Template.registerHelper 'formatBody', ->
  formatBody @format, @body

Template.registerHelper 'formatFile', ->
  formatFile @file

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
  subscribers: ->
    subscribers =
      for subscriber in sortedMessageSubscribers @_id
        linkToAuthor @group, subscriber
    if subscribers.length > 0
      subscribers.join(', ')
    else
      '(none)'
  orphans: ->
    orphans @_id
  orphanCount: ->
    count = orphans(@_id).count()
    if count > 0
      pluralize count, 'orphaned subthread'

Template.message.onCreated ->
  @autorun ->
    setTitle titleOrUntitled Template.currentData()

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
  setTimeout ->
    $('input.title').first().focus()
  , 100

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

messageRaw = new ReactiveDict
messageFolded = new ReactiveDict
messageHistory = new ReactiveDict
messageKeyboard = new ReactiveDict
defaultKeyboard = 'normal'

Template.submessage.onCreated ->
  @count = submessageCount++
  @editing = new ReactiveVar null
  @autorun =>
    #console.log 'editing autorun', Template.currentData()?._id, editing Template.currentData()
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

initImage = (id) ->
  if id not of images
    images[id] =
      attachment: null
      count: 0

messageDrag = (target, bodyToo = true) ->
  return unless target
  onDragStart = (e) =>
    #url = "coauthor:#{@data._id}"
    url = urlFor 'message',
      group: @data.group
      message: @data._id
    e.dataTransfer.effectAllowed = 'linkMove'
    e.dataTransfer.setData 'text/plain', url
    e.dataTransfer.setData 'application/coauthor-id', @data._id
    e.dataTransfer.setData 'application/coauthor-type', type
  type = 'message'
  if @data.file
    type = fileType @data.file
    #if "class='odd-file'" not in formatted and
    #   "class='bad-file'" not in formatted
    #  url = formatted
    if bodyToo
      $(@find '.message-file')?.find('img, video, a')?.each (i, elt) =>
        elt.addEventListener 'dragstart', onDragStart
  target.addEventListener 'dragstart', onDragStart

Template.submessage.onRendered ->
  ## Random message background color (to show nesting).
  #@firstNode.style.backgroundColor = '#' +
  #  Math.floor(Math.random() * 25 + 255 - 25).toString(16) +
  #  Math.floor(Math.random() * 25 + 255 - 25).toString(16) +
  #  Math.floor(Math.random() * 25 + 255 - 25).toString(16)

  ## Drag/drop support.
  focusButton = $(@find '.message-left-buttons').find('.focusButton')[0]
  messageDrag.call @, focusButton

  ## Fold deleted messages by default on initial load.
  messageFolded.set @data._id, true if @data.deleted

  ## Fold referenced attached files by default on initial load.
  #@$.children('.panel').children('.panel-body').find('a[href|="/gridfs/fs/"]')
  #console.log @$ 'a[href|="/gridfs/fs/"]'
  tid = @data._id
  id2template[@data._id] = @
  scrollToMessage @data._id if scrollToLater == @data._id
  attachment = @data.file
  #images = Session.get 'images'
  subimages = @images = []
  $(@firstNode).children('.panel-body').children('.message-file').find('img[src^="/gridfs/fs/"]')
  .each ->
    id = url2file @getAttribute('src')
    initImage id
    images[id].attachment = tid
    if images[id].count > 0 and not messageFolded.get(images[id].attachment)?
      messageFolded.set images[id].attachment, true
  ## If message is deleted or otherwise default-folded,
  ## don't check for images it references.
  unless messageFolded.get @data._id
    $(@firstNode).children('.panel-body').children('.message-body').find('img[src^="/gridfs/fs/"]')
    .each ->
      id = url2file @getAttribute('src')
      initImage id
      subimages.push id
      images[id].count += 1
      if images[id].attachment? and not messageFolded.get(images[id].attachment)?
        messageFolded.set images[id].attachment, true

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
  for id in @images ? []
    if id of images
      images[id].count -= 1

historify = (x, post) -> () ->
  history = messageHistory.get @_id
  value =
    if history?
      history[x]
    else
      @[x]
  if post?
    value = post value
  value

tabindex = (i) -> 
  1 + 20 * Template.instance().count + parseInt(i ? 0)

absentTags = ->
  data = Template.currentData()
  Tags.find
    group: data.group
    key: $nin: _.keys data.tags ? {}
    deleted: false
  ,
    sort: ['key']

Template.submessage.helpers
  tabindex: tabindex
  tabindex5: -> tabindex 5
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
      switch sharejsEditor
        when 'cm'
          editor.getInputField().setAttribute 'tabindex', 1 + 20 * ti.count + 19
          ## styleActiveLine is currently buggy on Android.
          if 0 > navigator.userAgent.toLowerCase().indexOf 'android'
            editor.setOption 'styleActiveLine', true
          editor.setOption 'matchBrackets', true
          editor.setOption 'lineWrapping', true
          editor.setOption 'lineNumbers', true
          editor.setOption 'showCursorWhenSelecting', true
          editor.setOption 'matchBrackets', true
          editor.setOption 'foldGutter', true
          editor.setOption 'gutters', [
            'CodeMirror-linenumbers'
            'CodeMirror-foldgutter'
          ]
          editor.setOption 'theme',
            switch theme()
              when 'dark'
                'blackboard'
              when 'light'
                'eclipse'
              else
                theme()
          editor.setOption 'extraKeys',
            Enter: 'newlineAndIndentContinueMarkdownList'
            End: 'goLineRight'
            Home: 'goLineLeft'
          cmDrop = editor.display.dragFunctions.drop
          editor.setOption 'dragDrop', false
          editor.display.dragFunctions.drop = (e) ->
            #text = e.dataTransfer.getData 'text'
            id = e.dataTransfer?.getData 'application/coauthor-id'
            if id
              type = e.dataTransfer.getData 'application/coauthor-type'
              e.preventDefault()
              e = _.omit e, 'dataTransfer', 'preventDefault'
              e.defaultPrevented = false
              e.preventDefault = ->
              e.dataTransfer =
                getData: ->
                  switch type
                    when 'image'
                      switch ti.data.format
                        when 'markdown'
                          "![](coauthor:#{id})"
                        when 'latex'
                          "\\includegraphics{coauthor:#{id}}"
                        when 'html'
                          """<img src="coauthor:#{id}">"""
                    when 'video'
                      """<video controls><source src="coauthor:#{id}"></video>"""
                    else
                      "coauthor:#{id}"
            cmDrop e
          editor.setOption 'dragDrop', true
        when 'ace'
          editor.textInput.getElement().setAttribute 'tabindex', 1 + 20 * ti.count + 19
          #editor.meteorData = @  ## currently not needed, also dunno if works
          editor.$blockScrolling = Infinity
          #editor.on 'change', onChange
          editor.setTheme 'ace/theme/' +
            switch theme()
              when 'dark'
                'vibrant_ink'
              when 'light'
                'chrome'
              else
                theme()
          editor.setShowPrintMargin false
          editor.setBehavioursEnabled true
          editor.setShowFoldWidgets true
          editor.getSession().setUseWrapMode true
          #editor.setOption 'spellcheck', true
          #editor.container.addEventListener 'drop', (e) =>
          #  e.preventDefault()
          #  if id = e.dataTransfer.getData('application/coauthor')
          #    #switch @format
          #    #  when 'latex'
          #    #    e.dataTransfer.setData('text/plain', "\\href{#{id}}{}")
          #    e.dataTransfer.setData('text/plain', "<IMG SRC='coauthor:#{id}'>")
      editorMode editor, ti.data.format
      editorKeyboard editor, messageKeyboard.get(ti.data._id) ? defaultKeyboard

  keyboard: ->
    capitalize messageKeyboard.get(@_id) ? defaultKeyboard
  activeKeyboard: (match) ->
    if (messageKeyboard.get(@_id) ? defaultKeyboard) == match
      'active'
    else
      ''

  tags: historify 'tags', sortTags
  deleted: historify 'deleted'
  published: historify 'published'

  tex2jax: ->
    history = messageHistory.get(@_id) ? @
    if history.format in mathjaxFormats
      'tex2jax'
    else
      ''
  title: historify 'title'
  formatTitle: ->
    history = messageHistory.get(@_id) ? @
    if messageRaw.get @_id
      "<CODE CLASS='raw'>#{_.escape history.title}</CODE>"
    else
      formatTitleOrFilename history, false  ## don't write (untitled)
  formatBody: ->
    history = messageHistory.get(@_id) ? @
    body = history.body
    return body unless body
    if messageRaw.get @_id
      "<PRE CLASS='raw'>#{_.escape body}</PRE>"
    else
      formatBody history.format, body
  formatFile: ->
    history = messageHistory.get(@_id) ? @
    file = history.file
    return file unless file
    file = formatFile file
    if messageRaw.get @_id
      "<PRE CLASS='raw'>#{_.escape file}</PRE>"
    else
      file
  formatFileDescription: ->
    formatFileDescription @file  ## always editing so not in history

  canEdit: -> canEdit @_id
  canDelete: -> canDelete @_id
  canUndelete: -> canUndelete @_id
  canPublish: -> canPublish @_id
  canUnpublish: -> canUnpublish @_id
  canSuperdelete: -> canSuperdelete @_id
  canPrivate: -> canPrivate @_id

  history: -> messageHistory.get(@_id)?
  forHistory: ->
    _id: @_id
    history: messageHistory.get @_id

  folded: -> messageFolded.get @_id
  raw: -> messageRaw.get @_id
  prev: -> messageNeighbors(@)?.prev
  next: -> messageNeighbors(@)?.next

  absentTags: absentTags
  absentTagsCount: ->
    absentTags().count()

Template.registerHelper 'messagePanelClass', ->
  editingClass =
    if Template.instance().editing?.get()
      ' editing'
    else
      ''
  if @deleted
    "panel-danger message-deleted #{editingClass}"
  else
    unless @published
      "panel-warning message-unpublished #{editingClass}"
    else if @private
      "panel-info message-private #{editingClass}"
    else
      "panel-primary message-public #{editingClass}"

Template.registerHelper 'formatCreator', ->
  linkToAuthor @group, @creator

Template.registerHelper 'creator', ->
  displayUser @creator

Template.registerHelper 'formatAuthors', ->
  a = for own author, date of @authors when author != @creator or date.getTime() != @created.getTime()
        "#{linkToAuthor @group, unescapeUser author} #{formatDate date, 'on '}"
  if a.length > 0
    ', edited by ' + a.join ", "

Template.submessage.events
  'click .tagRemove': (e, t) ->
    e.preventDefault()
    e.stopPropagation()
    message = t.data._id
    tags = t.data.tags
    tag = e.target.getAttribute 'data-tag'
    if tag of tags
      delete tags[escapeTag tag]
      Meteor.call 'messageUpdate', message,
        tags: tags
      Meteor.call 'tagDelete', t.data.group, tag, true
    else
      console.warn "Attempt to delete nonexistant tag '#{tag}' from message #{message}"

  'click .tagAdd': (e, t) ->
    e.preventDefault()
    e.stopPropagation()
    message = t.data._id
    tags = t.data.tags
    tag = e.target.getAttribute 'data-tag'
    if tag of tags
      console.warn "Attempt to add duplicate tag '#{tag}' to message #{message}"
    else
      tags[escapeTag tag] = true
      Meteor.call 'messageUpdate', message,
        tags: tags
    dropdownToggle e

  'click .tagAddNew': (e, t) ->
    e.preventDefault()
    e.stopPropagation()
    message = t.data._id
    tags = t.data.tags ? {}
    textTag = $(e.target).parents('form').first().find('.tagAddText')[0]
    tag = textTag.value.trim()
    textTag.value = ''  ## reset custom tag
    if tag
      if tag of tags
        console.warn "Attempt to add duplicate tag '#{tag}' to message #{message}"
      else
        Meteor.call 'tagNew', t.data.group, tag, 'boolean'
        tags[escapeTag tag] = true
        Meteor.call 'messageUpdate', message,
          tags: tags
    dropdownToggle e
    false  ## prevent form from submitting

  'click .foldButton': (e, t) ->
    e.preventDefault()
    e.stopPropagation()
    messageFolded.set @_id, not messageFolded.get @_id

  'click .rawButton': (e, t) ->
    e.preventDefault()
    e.stopPropagation()
    messageRaw.set @_id, not messageRaw.get @_id

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

  'click .privateButton': (e, t) ->
    e.preventDefault()
    e.stopPropagation()
    message = t.data._id
    Meteor.call 'messageUpdate', message,
      private: not @private

  'click .editorKeyboard': (e, t) ->
    e.preventDefault()
    e.stopPropagation()
    messageKeyboard.set @_id, kb = e.target.getAttribute 'data-keyboard'
    editorKeyboard t.editor, kb
    dropdownToggle e

  'click .editorFormat': (e, t) ->
    e.preventDefault()
    e.stopPropagation()
    Meteor.call 'messageUpdate', t.data._id,
      format: format = e.target.getAttribute 'data-format'
    editorMode Template.instance().editor, format
    dropdownToggle e

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
      msg = {}
      privacy = e.target.getAttribute 'data-privacy'
      switch privacy
        when 'public'
          msg.private = false
        when 'private'
          msg.private = true
      Meteor.call 'messageNew', @group, @_id, null, msg, (error, result) ->
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
    if messageHistory.get(@_id)?
      messageHistory.set @_id, null
    else
      messageHistory.set @_id, _.clone @

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
      messageHistory.set @data._id, diffs[e.newValue]
    messageHistory.set @data._id, diffs[diffs.length-1]

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
        file: file2.uniqueIdentifier
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
        file: file2.uniqueIdentifier
    file.group = group
    Files.resumable.addFile file, e

uploader 'messageReplace', 'replaceButton', 'replaceInput', replaceFiles

Template.messageAuthor.helpers
  creator: ->
    "!" + @creator

privacyOptions = [
  code: 'public'
  list: ['public']
  display: 'Public messages only (usual behavior)'
,
  code: 'both'
  list: ['public', 'private']
  display: 'Public and private messages (for feedback)'
,
  code: 'private'
  list: ['private']
  display: 'Private messages only (for solved problems)'
]
privacyOptionsByCode = {}
for option in privacyOptions
  privacyOptionsByCode[option.code] = option

Template.threadPrivacy.helpers
  privacyOptions: privacyOptions
  active: ->
    if _.isEqual(_.sortBy(privacyOptionsByCode[@code].list),
                 _.sortBy(Template.parentData(2).threadPrivacy ? ['public']))
      'active'
    else
      ''

Template.threadPrivacy.events
  'click .threadPrivacy': (e, t) ->
    e.preventDefault()
    e.stopPropagation()
    Meteor.call 'threadPrivacy', Template.parentData()._id,
      privacyOptionsByCode[e.target.getAttribute 'data-code'].list
    dropdownToggle e

Template.replyButtons.helpers
  canReply: -> canPost @group, @_id
  canAttach: -> canPost @group, @_id
  canPublicReply: -> 'public' in (@threadPrivacy ? ['public'])
  canPrivateReply: -> 'private' in (@threadPrivacy ? ['public'])

Template.tableOfContentsMessage.helpers
  parentId: ->
    Template.parentData()._id

Template.tableOfContentsMessage.onRendered ->
  messageDrag.call @, @find('a'), false

addDragOver = (e) ->
  e.preventDefault()
  e.stopPropagation()
  $(e.target).addClass 'dragover'

removeDragOver = (e) ->
  e.preventDefault()
  e.stopPropagation()
  $(e.target).removeClass 'dragover'

dragOver = (e) ->
  e.preventDefault()
  e.stopPropagation()

dropOn = (e, t) ->
  e.preventDefault()
  e.stopPropagation()
  $(e.target).removeClass 'dragover'
  dragId = e.originalEvent.dataTransfer?.getData 'application/coauthor-id'
  dropId = e.target.getAttribute 'data-id'
  if dragId and dropId
    messageParent dragId, dropId

dropBefore = (e, t) ->
  e.preventDefault()
  e.stopPropagation()
  $(e.target).removeClass 'dragover'
  dragId = e.originalEvent.dataTransfer?.getData 'application/coauthor-id'
  dropId = e.target.getAttribute 'data-parent'
  index = e.target.getAttribute 'data-index'
  if dragId and dropId and index
    index = parseInt index
    messageParent dragId, dropId, index

for template in [Template.tableOfContentsRoot, Template.tableOfContentsMessage]
  template.events
    "dragenter .onMessageDrop": addDragOver
    "dragleave .onMessageDrop": removeDragOver
    "dragover .onMessageDrop": dragOver
    "dragenter .beforeMessageDrop": addDragOver
    "dragleave .beforeMessageDrop": removeDragOver
    "dragover .beforeMessageDrop": dragOver
    "drop .onMessageDrop": dropOn
    "drop .beforeMessageDrop": dropBefore

messageParent = (child, parent, index = null) ->
  #console.log 'messageParent', child, parent, index
  #Meteor.call 'messageParent', child, parent, index
  return if child == parent  ## ignore trivial self-loop
  childMsg = Messages.findOne child
  parentMsg = Messages.findOne parent
  oldParent = findMessageParent child
  oldIndex = oldParent?.children.indexOf child
  ## Ignore drag to same place
  if parentMsg?._id == oldParent?._id
    return if index == oldIndex or
      (not index? and oldIndex == oldParent.children.length - 1)
  Modal.show 'messageParentConfirm',
    child: childMsg
    parent: parentMsg
    oldParent: oldParent
    index: index
    oldIndex: oldIndex

Template.messageParentConfirm.events
  "click .messageParentButton": (e, t) ->
    e.preventDefault()
    e.stopPropagation()
    Modal.hide()
    Meteor.call 'messageParent', t.data.child._id, t.data.parent._id, t.data.index
  "click .cancelButton": (e) ->
    e.preventDefault()
    e.stopPropagation()
    Modal.hide()
