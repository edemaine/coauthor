import { resolveTheme } from './theme.coffee'

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

@dropdownToggle = (e) ->
  #$(e.target).parent().dropdown 'toggle'
  $(e.target).parents('.dropdown-menu').first().parent().find('.dropdown-toggle').dropdown 'toggle'
  $(e.target).tooltip 'hide'

@routeMessage = ->
  Router.current()?.params?.message

Template.registerHelper 'titleOrUntitled', ->
  titleOrUntitled @

Template.registerHelper 'childrenCount', ->
  return 0 unless @children and @children.length > 0
  msgs = Messages.find
    _id: $in: @children
  .fetch()
  msgs = (msg for msg in msgs when canSee msg)
  msgs.length

Template.registerHelper 'childLookup', (index) ->
  ## Usage:
  ##   each children
  ##     with childLookup @index
  ## Assumes `this` is a String object whose value is a message ID,
  ## and the argument is the index of interation.  Fetches the message,
  ## and populates it with additional `index` and `parent` fields.
  ## In this careful usage, we don't spill reactive dependencies
  ## between parents and children.
  #console.log 'looking up', @valueOf()
  msg = Messages.findOne @valueOf()
  return msg unless msg
  ## Use canSee to properly fake non-superuser mode.
  return unless canSee msg
  ## Import _id information from parent nonreactively.
  ## If we get reparented, a totally new template should get created,
  ## so we don't need to be reactive to changes to parentData.
  parentData = Tracker.nonreactive -> Template.parentData()
  msg.parent = parentData._id
  #msg.depth = parentData.depth
  msg.index = index
  msg

Template.registerHelper 'tags', ->
  sortTags @tags

Template.registerHelper 'linkToTag', ->
  #pathFor 'tag',
  #  group: Template.parentData().group
  #  tag: @key
  pathFor 'search',
    group: Template.parentData().group
    search: "tag:#{@key}"

Template.registerHelper 'folded', ->
  (messageFolded.get @_id) and
  (not here @_id) and                       # never fold if top-level message
  (not Template.instance()?.editing?.get()) # never fold if editing

Template.rootHeader.helpers
  root: ->
    if @root
      Messages.findOne @root

Template.registerHelper 'formatTitle', ->
  formatTitleOrFilename @, false

Template.registerHelper 'formatTitleOrUntitled', ->
  formatTitleOrFilename @, true

Template.registerHelper 'formatTitleBold', ->
  formatTitleOrFilename @, false, false, true

Template.registerHelper 'formatTitleOrUntitledBold', ->
  formatTitleOrFilename @, true, false, true

Template.registerHelper 'formatBody', ->
  formatBody @format, @body

Template.registerHelper 'formatFile', ->
  formatFile @

Template.messageMaybe.helpers
  matchingGroup: ->
    @group == routeGroup()

Template.messageMaybe.onRendered ->
  ## Redirect wild-group message link to group-specific link
  if routeGroup() == wildGroup
    Router.go 'message', {group: @group, message: @_id}

Template.messageBad.helpers
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

authorCountHelper = (field) -> ->
  tooltipUpdate()
  authors =
    for username, count of Session.get field
      continue unless count
      user: findUsername(username) ? username: username
      count: count
  authors = _.sortBy authors, (author) -> userSortKey author.user
  authors = _.sortBy authors, (author) -> -author.count
  authors =
    for author in authors
      "#{linkToAuthor @group, author.user} (#{author.count})"
  authors.join ', '

Template.message.helpers
  authors: authorCountHelper 'threadAuthors'
  mentions: authorCountHelper 'threadMentions'
  subscribers: ->
    tooltipUpdate()
    subscribers = messageSubscribers @_id,
      fields: username: true
    subscribed = {}
    for user in subscribers
      subscribed[user.username] = true
    users = sortedMessageReaders @_id,
      fields:
        username: true
        emails: true
        roles: true
        rolesPartial: true
        'profile.notifications': true
    unless users.length
      return '(none)'
    (for user in users
      title = "User '#{user.username}': " # like linkToAuthor
      if user.username of subscribed
        title += 'Subscribed to email notifications'
        icon = '<span class="fas fa-check"></span> ' #text-success
      else
        icon = '<span class="fas fa-times"></span> ' #text-danger
        unless user.emails?[0]?
          title += "No email address"
        else if not user.emails[0].verified
          title += "Unverified email address #{user.emails[0].address}"
        else if not (user.profile.notifications?.on ? defaultNotificationsOn)
          title += "Notifications turned off"
        else if not autosubscribe @group, user
          title += "Autosubscribe turned off, and not explicitly subscribed to thread"
        else
          title += "Explicitly unsubscribed from thread"
      linkToAuthor @group, user.username, title, icon
    ).join ', '
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
  tooltipInit()

  ## Give focus to first Title input, if there is one.
  setTimeout ->
    $('input.title').first().focus()
  , 100

editing = (self) ->
  Meteor.user()? and Meteor.user().username in (self.editing ? [])

safeToStopEditing = ->
  data = Template.currentData()
  instance = Template.instance()
  #data.editing.length > 1 or (
  data.title == instance.editTitle.get() and
  data.body == instance.editBody.get()

idle = 1000   ## one second

messageClass = ->
  if @deleted
    'deleted'
  else if not @published
    'unpublished'
  else if @private
    'private'
  else if @minimized
    'minimized'
  else
    'published'

Template.registerHelper 'messageClass', messageClass

submessageCount = 0

messageRaw = new ReactiveDict
export messageFolded = new ReactiveDict
defaultFolded = new ReactiveDict
messageHistory = new ReactiveDict
messageHistoryAll = new ReactiveDict
messageKeyboard = new ReactiveDict
messagePreview = new ReactiveDict
defaultHeight = 300
@messagePreviewDefault = ->
  profile = Meteor.user().profile?.preview
  on: profile?.on ? true
  sideBySide: profile?.sideBySide ? false
  height: profile?.height ? defaultHeight
## The following helpers should only be called when editing.
## They can be called in two settings:
##   * Within the submessage template, and possibly within a `with nothing`
##     data environment.  In this case, we use the `editing` ReactiveVar
##     to get the message ID, because we should be editing.
##   * From the betweenEditorAndBody subtemplate.  Then we can use `_id` data.
messagePreviewGet = (template = Template.instance()) ->
  unless id?
    id = template?.editing?.get()
    unless id?
      id = Template.currentData()?._id
      unless id?
        id = template?.data?._id
        return unless id?
  messagePreview.get(id) ? messagePreviewDefault()
messagePreviewSet = (change, template = Template.instance()) ->
  unless id?
    id = template?.editing?.get()
    unless id?
      id = Template.currentData()?._id
      unless id?
        id = template?.data?._id
        return unless id?
  preview = messagePreview.get(id) ? messagePreviewDefault()
  messagePreview.set id, change preview

export messageFoldHandler = (e, t) ->
  e.preventDefault()
  e.stopPropagation()
  messageFolded.set @_id, not messageFolded.get @_id
  $(e.currentTarget).tooltip 'hide'
  tooltipUpdate()

threadAuthors = {}
threadMentions = {}

Template.submessage.onCreated ->
  @count = submessageCount++
  @editing = new ReactiveVar null
  @editStopping = new ReactiveVar false
  @editTitle = new ReactiveVar null
  @editBody = new ReactiveVar null
  @lastTitle = null
  @savedTitles = []

  @autorun =>
    data = Template.currentData()
    return unless data?
    #@myid = data._id
    if editing data
      ## Maintain @editing == this message's ID when message is being edited.
      ## Also initialize title and body only when we start editing.
      if data._id != @editing.get()
        @editing.set data._id
        @editTitle.set data.title
        @editBody.set data.body
      ## Update input's value when title changes on server
      if data.title != @lastTitle
        @lastTitle = data.title
        ## Ignore an update that matches a title we sent to the server,
        ## to avoid weird reversion while live typing with network delays.
        ## (In steady state, we expect our saves to match later updates,
        ## so this should acquiesce with an empty savedTitles.)
        if data.title in @savedTitles
          while @savedTitles.pop() != data.title
            continue
        else
          ## Received new title: update input text, forget past saves,
          ## and cancel any pending save.
          @editTitle.set data.title
          @savedTitles = []
          Meteor.clearTimeout @timer
    else
      @editing.set null

    threadAuthors[author] -= 1 for author in @authors if @authors?
    threadMentions[author] -= 1 for author in @mentions if @mentions?
    @authors = (unescapeUser author for author of data.authors)
    for author in @authors
      threadAuthors[author] ?= 0
      threadAuthors[author] += 1
    Session.set 'threadAuthors', threadAuthors
    @mentions = atMentions data
    for author in @mentions
      threadMentions[author] ?= 0
      threadMentions[author] += 1
    Session.set 'threadMentions', threadMentions

    #console.log 'automathjax'
    automathjax()

  ## Fold naturally folded (minimized and deleted) messages by default on
  ## initial load.  But only if not previously manually overridden.
  oldDefault = defaultFolded.get @data._id
  oldFolded = messageFolded.get @data._id
  defaultFolded.set @data._id, naturallyFolded @data

  ## Fold referenced attached files by default on initial load.
  #@$.children('.panel').children('.panel-body').find('a[href|="/file/"]')
  #console.log @$ 'a[href|="/file/"]'
  #images = Session.get 'images'
  @images = {}
  @imagesInternal = {}
  @autorun =>
    data = Template.currentData()
    return unless data._id
    initImage data._id
    ## initImage calls updateFileQuery which will do this:
    #images[data._id].file = data.file
    #initImageInternal data.file if data.file?
    id2template[data._id] = @
    ## If message is naturally folded, don't count images it references.
    images[data._id].naturallyFolded = naturallyFolded data
    images[data._id].children = data.children?.length
    if images[data._id].naturallyFolded
      for id of @images
        images[id].count -= 1
        checkImage id
      @images = {}
      for id of @imagesInternal
        imagesInternal[id].count -= 1
        checkImageInternal id
      @imagesInternal = {}
    else
      newImages = {}
      newImagesInternal = {}
      $($.parseHTML("<div>#{formatBody data.format, data.body}</div>"))
      .find """
        img[src^="#{fileUrlPrefix}"],
        img[src^="#{fileAbsoluteUrlPrefix}"],
        img[src^="#{internalFileUrlPrefix}"],
        img[src^="#{internalFileAbsoluteUrlPrefix}"],
        video source[src^="#{fileUrlPrefix}"],
        video source[src^="#{fileAbsoluteUrlPrefix}"],
        video source[src^="#{internalFileUrlPrefix}"],
        video source[src^="#{internalFileAbsoluteUrlPrefix}"]
      """
      .each ->
        src = @getAttribute('src')
        if 0 <= src.indexOf 'gridfs'
          newImagesInternal[url2internalFile src] = true
        else
          newImages[url2file src] = true
      for id of @images
        unless id of newImages
          images[id].count -= 1
          checkImage id
      for id of newImages
        unless id of @images
          #console.log 'source', id
          initImage id
          images[id].count += 1
          checkImage id
      @images = newImages
      for id of @imagesInternal
        unless id of newImagesInternal
          imagesInternal[id].count -= 1
          checkImageInternal id
      for id of newImagesInternal
        unless id of @imagesInternal
          #console.log 'source', id
          initImageInternal id
          imagesInternal[id].count += 1
          checkImageInternal id
      @imagesInternal = newImagesInternal

  ## Switch messageFolded to defaultFolded if:
  ## * default has changed
  ## * default has initialized but messageFolded not already set
  ##   (e.g. because we just clicked the message)
  if oldFolded? and (not oldDefault? or oldDefault == defaultFolded.get @data._id)
    unless oldFolded == messageFolded.get @data._id
      messageFolded.set @data._id, oldFolded
  else
    messageFolded.set @data._id, defaultFolded.get @data._id

#Session.setDefault 'images', {}
images = {}
imagesInternal = {}
id2template = {}
scrollToLater = null
fileQuery = null

updateFileQuery = _.debounce ->
  fileQuery.stop() if fileQuery?
  fileQuery = Messages.find
    _id: $in: _.keys images
  ,
    fields: file: true
  .observeChanges
    added: (id, fields) ->
      #console.log "#{id} added:", fields
      images[id].file = fields.file
      if images[id].file?
        initImageInternal images[id].file, id
        checkImageInternal images[id].file
    changed: (id, fields) ->
      #console.log "#{id} changed:", fields
      if fields.file? and images[id].file != fields.file
        if fileType(fields.file) in ['image', 'video']
          forceImgReload urlToFile id
        imagesInternal[images[id].file].image = null if images[id].file?
        images[id].file = fields.file
        if images[id].file?
          initImageInternal images[id].file, id
          checkImageInternal images[id].file
, 250

initImage = (id) ->
  if id not of images
    images[id] =
      count: 0
      file: null
    updateFileQuery()

initImageInternal = (id, image = null) ->
  #console.log "initImageInternal #{id}, #{image}"
  if id not of imagesInternal
    imagesInternal[id] =
      count: 0
      image: image
  else if image?
    imagesInternal[id].image = image

checkImage = (id) ->
  return unless id of images
  ## Image gets unnaturally folded if it's referenced at least once
  ## and doesn't have any children (don't want to hide children, and this
  ## can also lead to infinite loop if children has the image reference).
  newDefault = images[id].naturallyFolded or
    (not images[id].children and
     (images[id].count > 0 or
      (imagesInternal[images[id].file]? and
       imagesInternal[images[id].file].count > 0)))
  if newDefault != defaultFolded.get id
    defaultFolded.set id, newDefault
    messageFolded.set id, newDefault
  ## No longer care about this image if it's not referenced and doesn't have
  ## a rendered template.
  if images[id].count == 0 and id not of id2template
    delete images[id]
    updateFileQuery()

checkImageInternal = (id) ->
  image = imagesInternal[id].image
  #console.log "#{id} corresponds to #{image}"
  checkImage image if image?

messageDrag = (target, bodyToo = true, old) ->
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
    #console.log @data.file, type
    #if "class='odd-file'" not in formatted and
    #   "class='bad-file'" not in formatted
    #  url = formatted
    if bodyToo
      $(@find '.message-file')?.find('img, video, a, canvas')?.each (i, elt) =>
        elt.removeEventListener 'dragstart', old if old?
        elt.addEventListener 'dragstart', onDragStart
  target.removeEventListener 'dragstart', old if old?
  target.addEventListener 'dragstart', onDragStart
  onDragStart

## A message is "naturally" folded if it is flagged as minimized or deleted.
## It still will be default-folded if it's an image referenced in another
## message that is not naturally folded.
export naturallyFolded = (data) -> data.minimized or data.deleted

Template.submessage.onRendered ->
  ## Random message background color (to show nesting).
  #@firstNode.style.backgroundColor = '#' +
  #  Math.floor(Math.random() * 25 + 255 - 25).toString(16) +
  #  Math.floor(Math.random() * 25 + 255 - 25).toString(16) +
  #  Math.floor(Math.random() * 25 + 255 - 25).toString(16)

  ## Drag/drop support.
  focusButton = $(@find '.message-left-buttons').find('.focusButton')[0]
  @autorun =>
    listener = messageDrag.call @, focusButton, true, listener

  ## Scroll to this message if it's been requested.
  if scrollToLater == @data._id
    scrollToMessage @data._id

  ## Image rotation. Also triggered in formatBody.
  @autorun =>
    data = Template.currentData()  ## update whenever message does
    messageFolded.get data._id     ## update when message is unfolded
    messageRaw.get data._id        ## update when raw mode turned off
    messageRotate data             ## update when file orientation gets loaded
    #console.log 'rotating', data._id, data.body, messageRotate data
    Meteor.defer => messageImageTransform.call @
  window.addEventListener 'resize',
    @onResize = _.debounce (=> messageImageTransform.call @), 100

  ## Update side-by-side height settings when leaving editing mode
  ## and/or changing side-by-side preview setting.
  @autorun =>
    preview = messagePreviewGet()
    return unless preview?
    @editor?.setSize null, preview.height
    @$('.bodyContainer').first().height \
      if @editing.get() and preview.sideBySide
        preview.height
      else
        'auto'

Template.submessage.onDestroyed ->
  window.removeEventListener 'resize', @onResize if @onResize?

## Cache EXIF orientations, as files should be static
image2orientation = {}
@messageRotate = (data) ->
  if data.file not of image2orientation
    file = findFile data.file
    if file
      image2orientation[data.file] = file.metadata?.exif?.Orientation
  exifRotate = Orientation2rotate[image2orientation[data.file]]
  (data.rotate ? 0) + (exifRotate ? 0)

## Callable from `submessage` and `readMessage` templates
@messageImageTransform = ->
  return unless @data?

  ## Transform any images embedded within message body
  for img in @findAll """
    .message-body img[src^="#{fileUrlPrefix}"],
    .message-body img[src^="#{fileAbsoluteUrlPrefix}"]
  """
    message = findMessage url2file img.src
    continue unless message
    imageTransform img, messageRotate message

  ## Transform image file, respecting history
  data = messageHistory.get(@data._id) ? @data
  if data.file and 'image' == fileType data.file
    image = @find '.message-file img'
    if image?
      imageTransform image, messageRotate data
    else
      ## This case occurs e.g. when switching to Raw mode.
      @find('.message-file')?.style.height = null

scrollDelay = 750

@scrollToMessage = (id) ->
  if id[0] == '#'
    id = id[1..]
  if id of id2template
    template = id2template[id]
    $('html, body').animate
      scrollTop: template.firstNode.offsetTop
    , 200, 'swing', ->
        $(template.find 'input.title').focus()
  else
    scrollToLater = id
    ## Unfold ancestors of clicked message so that it becomes visible.
    for ancestor from ancestorMessages id
      messageFolded.set ancestor._id, false
  ## Also unfold message itself, because you probably want to see it.
  messageFolded.set id, false

Template.submessage.onDestroyed ->
  delete id2template[@data._id]
  checkImage @data._id
  for id of @images ? {}
    if id of images
      images[id].count -= 1
      checkImage id

  threadAuthors[author] -= 1 for author in @authors if @authors?
  Session.set 'threadAuthors', threadAuthors
  threadMentions[author] -= 1 for author in @mentions if @mentions?
  Session.set 'threadMentions', threadMentions

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

here = (id) ->
  id? and Router.current().route?.getName() == 'message' and
  Router.current().params?.message == id

Template.submessage.helpers
  canReply: -> canPost @group, @_id
  tabindex: tabindex
  tabindex5: -> tabindex 5
  tabindex7: -> tabindex 7
  tabindex9: -> tabindex 9
  here: -> here @_id
  nothing: {}
  editingRV: -> Template.instance().editing.get()
  editingNR: -> Tracker.nonreactive -> Template.instance().editing.get()
  editStopping: -> Template.instance().editStopping.get()
  editTitle: -> Template.instance().editTitle.get()
  editData: ->
    #_.extend @,
    _id: @_id
    title: @title
    body: @body
    group: @group
    editing: @editing  ## to list other editors
    editStopping: Template.instance().editStopping.get()
    editTitle: Template.instance().editTitle.get()
    editBody: Template.instance().editBody.get()
  hideIfEditing: ->
    if Template.instance().editing.get()
      'hidden'
    else
      ''
  #myid: -> Tracker.nonreactive -> Template.instance().myid
  #editing: -> editing @
  config: ->
    height = Tracker.nonreactive -> messagePreviewGet()?.height
    ti = Tracker.nonreactive -> Template.instance()
    (editor) =>
      #console.log 'config', editor.getValue(), '.'
      ti.editor = editor
      switch sharejsEditor
        when 'cm'
          editor.setSize null, height
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
          theme = resolveTheme themeEditor()
          editor.setOption 'theme',
            switch theme
              when 'dark'
                'blackboard'
              when 'light'
                'eclipse'
              else
                theme
          pasteHTML = false
          editor.setOption 'extraKeys',
            Enter: 'xnewlineAndIndentContinueMarkdownList'
            End: 'goLineRight'
            Home: 'goLineLeft'
            "Shift-Ctrl-H": (cm) ->
              pasteHTML = not pasteHTML
              if pasteHTML
                console.log 'HTML pasting mode turned on.'
              else
                console.log 'HTML pasting mode turned off.'
          cmDrop = editor.display.dragFunctions.drop
          editor.setOption 'dragDrop', false
          editor.display.dragFunctions.drop = (e) ->
            text = e.dataTransfer?.getData 'text'
            id = e.dataTransfer?.getData 'application/coauthor-id'
            username = e.dataTransfer?.getData 'application/coauthor-username'
            type = e.dataTransfer?.getData 'application/coauthor-type'
            if username
              replacement = "@#{username}"
            else if id
              switch type
                when 'image', 'video', 'pdf'
                  switch ti.data.format
                    when 'markdown'
                      replacement = "![](coauthor:#{id})"
                    when 'latex'
                      replacement = "\\includegraphics{coauthor:#{id}}"
                    when 'html'
                      replacement = """<img src="coauthor:#{id}">"""
                #when 'video'
                #  """<video controls><source src="coauthor:#{id}"></video>"""
                else
                  replacement = "coauthor:#{id}"
            else if match = parseCoauthorMessageUrl text
              replacement = "coauthor:#{match.message}#{match.hash}"
            else if match = parseCoauthorAuthorUrl text
              replacement = "@#{match.author}"
            else
              replacement = text
            if replacement?
              e.preventDefault()
              e = _.omit e, 'dataTransfer', 'preventDefault'
              e.defaultPrevented = false
              e.preventDefault = ->
              e.dataTransfer =
                getData: -> replacement
            cmDrop e
          editor.setOption 'dragDrop', true

          paste = null
          editor.on 'paste', (cm, e) ->
            paste = null
            if pasteHTML and 'text/html' in e.clipboardData.types
              paste = e.clipboardData.getData 'text/html'
              .replace /<!--.*?-->/g, ''
              .replace /<\/?(html|head|body|meta)\b[^<>]*>/ig, ''
              .replace /<b\s+style="font-weight:\s*normal[^<>]*>([^]*?)<\/b>/ig, '$1'
              .replace /<span\s+style="([^"]*)"[^<>]*>([^]*?)<\/span>/ig, (match, style, body) ->
                body = "<i>#{body}</i>" if style.match /font-style:\s*italic/
                body = "<b>#{body}</b>" if style.match /font-weight:\s*[6789]00/
                body
              .replace /(\s+)(<\/i>(<\/b>)?|<\/b>)/, '$2$1'
              .replace /<(p|li) dir="ltr"/ig, '<$1'
              .replace /<(\w+[^<>]*) class=("[^"]*"|'[^']*')/ig, '<$1'
              .replace /<(p|li|ul|pre) style=("[^"]*"|'[^']*')/ig, '<$1'
              .replace /<\/(p|li)>/ig, ''
              .replace /(<li[^<>]*>)<p>/ig, '$1'
              .replace /<(li|ul|\/ul|br|p)\b/ig, '\n$&'
              .replace /&quot;/ig, '"'
              if (match = /^\s*<pre[^<>]*>([^]*)<\/pre>\s*$/.exec paste) and
                 0 > match[1].indexOf '<pre>'
                ## Treat a single <pre> block (such as pasted from Raw view)
                ## like a text paste, after parsing basic &chars;
                paste = match[1]
                .replace /&lt;/g, '<'
                .replace /&gt;/g, '>'
                .replace /&amp;/g, '&'
                .split /\r\n?|\n/
              else
                paste = paste.split /\r\n?|\n/
                ## Remove blank lines
                paste = (line for line in paste when line.length)
            else if 'text/plain' in e.clipboardData.types
              text = e.clipboardData.getData 'text/plain'
              if match = parseCoauthorMessageUrl text
                paste = ["coauthor:#{match.message}#{match.hash}"]
              else if match = parseCoauthorAuthorUrl text
                paste = ["@#{match.author}"]
          editor.on 'beforeChange', (cm, change) ->
            if change.origin == 'paste' and paste?
              change.text = paste
              paste = null

          lastAtWord = (cm) ->
            cursor = cm.getCursor()
            return null unless cursor.ch
            text = cm.getRange
              line: cursor.line
              ch: 0
            , cursor
            (/@[^\s@]*$/.exec text)?[0]
          users = null
          editor.on 'keyup', (cm, e) ->
            if (e.key.length == 1 or e.key == 'Backspace') and ## regular typing
               (word = lastAtWord cm)?  ## completable @mention
              word = word[1..]
              cm.showHint
                completeSingle: false
                hint: (cm) -> new Promise (callback) ->
                  users ?= _.sortBy (
                    (Meteor.users.find {}, fields:
                      username: 1
                      "profile.fullname": 1
                    ).map (user) ->
                      display = user.username
                      if user.profile.fullname
                        display += " (#{user.profile.fullname})"
                      lower = display.toLowerCase()
                      text: user.username + ' '
                      displayText: display
                      sort: lower
                      search: lower.replace /\s/g, ''
                  ), 'sort'
                  matches = (user for user in users \
                    when user.search.includes word.toLowerCase())
                  cursor = cm.getCursor()
                  callback
                    list: matches
                    from:
                      line: cursor.line
                      ch: cursor.ch - word.length
                    to: cursor
            else
              cm.execCommand 'closeHint'

        when 'ace'
          editor.textInput.getElement().setAttribute 'tabindex', 1 + 20 * ti.count + 19
          #editor.meteorData = @  ## currently not needed, also dunno if works
          editor.$blockScrolling = Infinity
          #editor.on 'change', onChange
          editor.setTheme 'ace/theme/' +
            switch themeEditor()
              when 'dark'
                'vibrant_ink'
              when 'light'
                'chrome'
              else
                themeEditor()
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
      editor.on 'change',
        _.debounce => ti.editBody.set editor.getDoc().getValue()
      , 100
      editorMode editor, ti.data.format
      editorKeyboard editor, messageKeyboard.get(ti.data._id) ? userKeyboard()

  tex2jax: ->
    history = messageHistory.get(@_id) ? @
    if history.format in mathjaxFormats
      'tex2jax'
    else
      ''
  title: historify 'title'
  formatTitle: historifiedFormatTitle = (bold = false) ->
    history = messageHistory.get(@_id) ? @
    if messageRaw.get @_id
      "<CODE CLASS='raw'>#{_.escape history.title}</CODE>"
    else
      formatTitleOrFilename history, false, false, bold  ## don't say (untitled)
  formatTitleBold: -> historifiedFormatTitle.call @, true
  formatBody: ->
    #console.log 'rendering', @_id
    history = messageHistory.get(@_id) ? @
    body = history.body
    ## Apply image settings (e.g. rotation) on embedded images and image files.
    t = Template.instance()
    Meteor.defer -> messageImageTransform.call t
    return body unless body
    ## Don't show raw view if editing (editor is a raw view)
    if messageRaw.get(@_id) and not Template.instance().editing?.get()
      "<PRE CLASS='raw'>#{_.escape body}</PRE>"
    else
      formatBody history.format, body
  file: historify 'file'
  pdf: ->
    history = messageHistory.get(@_id) ? @
    ## Don't run PDF render if in raw mode
    return if messageRaw.get(@_id) or "pdf" != fileType history.file
    history.file
  image: ->
    history = messageHistory.get(@_id) ? @
    'image' == fileType history.file
  formatFile: ->
    history = messageHistory.get(@_id) ? @
    format = formatFile history
    if messageRaw.get @_id
      "<PRE CLASS='raw'>#{_.escape format}</PRE>"
    else
      format
  formatFileDescription: ->
    formatFileDescription @  ## always editing so not in history

  canEdit: -> canEdit @_id
  canAction: ->
    canEdit @_id
    #canDelete(@_id) or canUndelete(@_id) or canPublish(@_id) or canUnpublish(@_id) or canSuperdelete(@_id) or canPrivate(@_id)
  canDelete: -> canDelete @_id
  canUndelete: -> canUndelete @_id
  canPublish: -> canPublish @_id
  canUnpublish: -> canUnpublish @_id
  canMinimize: -> canMinimize @_id
  canUnminimize: -> canUnminimize @_id
  canSuperdelete: -> canSuperdelete @_id
  canPrivate: -> canPrivate @_id
  canParent: -> canMaybeParent @_id

  history: -> messageHistory.get(@_id)?
  historyAll: -> messageHistoryAll.get @_id

  raw: -> messageRaw.get @_id

  preview: ->
    messageHistory.get(@_id)? or
    (messagePreviewGet() ? on: true).on  ## on if not editing
  sideBySide: -> messagePreviewGet()?.sideBySide
  previewSideBySide: ->
    preview = messagePreviewGet()
    preview?.on and preview?.sideBySide
  sideBySideClass: ->
    if Template.instance().editing.get()
      preview = messagePreviewGet()
      if preview? and preview.on and preview.sideBySide
        'sideBySide'
      else
        ''
    else
      ''  ## no side-by-side if we're not editing

  absentTags: absentTags
  absentTagsCount: ->
    absentTags().count()

Template.messageTags.helpers
  tags: historify 'tags', sortTags

Template.messageLabels.helpers
  deleted: historify 'deleted'
  published: historify 'published'
  minimized: historify 'minimized'
  private: historify 'private'

Template.messageNeighbors.helpers
  parent: ->
    if @_id
      tooltipUpdate()
      findMessageParent @_id
      #parent = findMessageParent @_id
      #parent.child = @_id
      #parent
  prev: ->
    tooltipUpdate()
    messageNeighbors(@)?.prev
  next: ->
    tooltipUpdate()
    messageNeighbors(@)?.next

Template.belowEditor.helpers
  preview: -> messagePreviewGet()?.on
  sideBySide: -> messagePreviewGet()?.sideBySide
  changedHeight: ->
    height = messagePreviewGet()?.height
    height? and height != (Meteor.user()?.profile?.preview?.height ? defaultHeight)
  saved: ->
    @title == @editTitle and @body == @editBody
  otherEditors: ->
    tooltipUpdate()
    others = _.without @editing, Meteor.user()?.username
    if others.length > 0
      " Editing with #{(linkToAuthor @group, other for other in others).join ', '}."
    else
      ''

panelClass =
  deleted: 'panel-danger'
  unpublished: 'panel-warning'
  private: 'panel-info'
  minimized: 'panel-success'
  published: 'panel-primary'
Template.registerHelper 'messagePanelClass', ->
  #console.log 'rendering', @_id, @
  classes = []
  classes.push mclass = messageClass.call @
  classes.push panelClass[mclass]
  if Template.instance().editing?.get()
    classes.push 'editing'
  classes.join ' '

Template.registerHelper 'foldedClass', ->
  if (not here @_id) and messageFolded.get @_id
    'folded'
  else
    ''

Template.registerHelper 'formatCreator', ->
  tooltipUpdate()
  linkToAuthor @group, @creator

Template.registerHelper 'creator', ->
  displayUser @creator

Template.registerHelper 'formatAuthors', formatAuthors = ->
  tooltipUpdate()
  a = for own author, date of @authors
        author = unescapeUser author
        continue if author == @creator and date.getTime() == @created?.getTime()
        "#{linkToAuthor @group, author} #{formatDate date, 'on '}"
  if a.length > 0
    ', edited by ' + a.join ", "

Template.keyboardSelector.helpers
  keyboard: ->
    if @_id?
      capitalize messageKeyboard.get(@_id) ? userKeyboard()
    else  ## Settings
      capitalize (@keyboard ? defaultKeyboard)
  activeKeyboard: (match) ->
    active =
      if @_id?
        (messageKeyboard.get(@_id) ? userKeyboard()) == match
      else  ## Settings
        (@keyboard ? defaultKeyboard) == match
    if active
      'active'
    else
      ''

Template.submessage.events
  'click .tagRemove': (e, t) ->
    e.preventDefault()
    e.stopPropagation()
    message = t.data._id
    tags = t.data.tags
    tag = e.currentTarget.getAttribute 'data-tag'
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

  'click .foldButton': messageFoldHandler
  'click .focusButton': (e) -> $(e.currentTarget).tooltip 'hide'

  'click .rawButton': (e, t) ->
    e.preventDefault()
    e.stopPropagation()
    messageRaw.set @_id, not messageRaw.get @_id

  'click .editButton': (e, t) ->
    e.preventDefault()
    e.stopPropagation()
    message = @_id  #e.target.getAttribute 'data-message'
    if editing @
      stop = -> Meteor.call 'messageEditStop', message
      if safeToStopEditing()
        stop()
      else
        t.editStopping.set true
        t.autorun (computation) ->
          if safeToStopEditing()
            t.editStopping.set false
            stop()
            computation.stop()
    else
      Meteor.call 'messageEditStart', message

  'click .togglePreview': (e, t) ->
    e.preventDefault()
    e.stopPropagation()
    messagePreviewSet (preview) -> _.extend {}, preview,
      on: not preview.on

  'click .sideBySidePreview': (e, t) ->
    e.preventDefault()
    e.stopPropagation()
    messagePreviewSet (preview) -> _.extend {}, preview,
      sideBySide: not preview.sideBySide

  'click .publishButton': (e, t) ->
    e.preventDefault()
    e.stopPropagation()
    message = t.data._id
    ## Stop editing if we are publishing.
    #if not @published and editing @
    #  Meteor.call 'messageEditStop', message
    Meteor.call 'messageUpdate', message,
      published: not @published
      finished: true
    dropdownToggle e

  'click .deleteButton': (e, t) ->
    e.preventDefault()
    e.stopPropagation()
    message = t.data._id
    messageFolded.set message, not @deleted or @minimized or images[@_id]?.count > 0
    ## Stop editing if we are deleting.
    if not @deleted and editing @
      Meteor.call 'messageEditStop', message
    Meteor.call 'messageUpdate', message,
      deleted: not @deleted
      finished: true
    dropdownToggle e

  'click .privateButton': (e, t) ->
    e.preventDefault()
    e.stopPropagation()
    message = t.data._id
    Meteor.call 'messageUpdate', message,
      private: not @private
      finished: true
    dropdownToggle e

  'click .minimizeButton': (e, t) ->
    e.preventDefault()
    e.stopPropagation()
    message = t.data._id
    messageFolded.set message, @deleted or not @minimized or images[@_id]?.count > 0
    Meteor.call 'messageUpdate', message,
      minimized: not @minimized
      finished: true
    dropdownToggle e

  'click .parentButton': (e, t) ->
    e.preventDefault()
    e.stopPropagation()
    child = t.data
    oldParent = findMessageParent child
    oldIndex = oldParent?.children.indexOf child._id
    Modal.show 'messageParentDialog',
      child: child
      oldParent: oldParent
      oldIndex: oldIndex

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

  'input input.title': (e, t) ->
    e.stopPropagation()
    message = t.data._id
    Meteor.clearTimeout t.timer
    newTitle = e.target.value
    t.editTitle.set newTitle
    t.timer = Meteor.setTimeout ->
      t.savedTitles.push newTitle
      Meteor.call 'messageUpdate', message,
        title: newTitle
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

  'click .historyAllButton': (e, t) ->
    e.preventDefault()
    e.stopPropagation()
    messageHistoryAll.set @_id, not messageHistoryAll.get @_id

  'click .superdeleteButton': (e) ->
    e.preventDefault()
    e.stopPropagation()
    Modal.show 'superdelete', @

  'click .replaceButton': (e, t) ->
    e.preventDefault()
    e.stopPropagation()

  'click .setHeight': (e, t) ->
    e.preventDefault()
    e.stopPropagation()
    Meteor.users.update Meteor.userId(),
      $set: "profile.preview.height": messagePreviewGet()?.height

  'mousedown .resizer': (start, t) ->
    $(start.target).addClass 'active'
    oldHeight = t.$('.CodeMirror').height()
    $(document).mousemove mover = (move) ->
      messagePreviewSet ((preview) -> _.extend {}, preview,
        height: Math.max 100, oldHeight + move.clientY - start.clientY
      ), t
    cancel = (e) ->
      $(start.target).removeClass 'active'
      $(document).off 'mousemove', mover
      $(document).off 'mouseup', cancel
      $(document).off 'mouseleave', cancel
    $(document).mouseup cancel
    $(document).mouseleave cancel

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
  `import('bootstrap-slider')`.then (Slider) =>
    Slider = Slider.default
    diffs = []
    @autorun =>
      previous = messageHistory.get(@data._id)?.diffId
      if @slider?
        @slider.destroy()
        @slider = null
        ## Rehide slider's <input> in case we don't make one in this round.
        @find('input').style.display = 'none'
      diffs = MessagesDiff.find
        id: @data._id
      ,
        sort: ['updated']
      .fetch()
      ## Accumulate diffs
      for diff, i in diffs
        diff.diffId = diff._id
        diff._id = @data._id
        if i == 0  # first diff
          diff.creator = @data.creator
          diff.created = @data.created
          diff.authors = {}
        else  # later diff
          diff.authors = _.extend {}, diffs[i-1].authors  # avoid aliasing
          for own key, value of diffs[i-1] when key != 'finished'
            unless key of diff
              diff[key] = value
        for author in diff.updators ? []
          diff.authors[escapeUser author] = diff.updated
      ## Restrict to finished diffs if requested, preserving last chosen diff
      index = -1
      unless messageHistoryAll.get @data._id
        finished = []
        for diff, i in diffs
          if diff.diffId == previous
            index = finished.length
          if diff.finished or i == diffs.length - 1
            finished.push diff
        diffs = finished
      else
        for diff, i in diffs
          if diff.diffId == previous
            index = i
            break
      unless 0 <= index < diffs.length
        index = diffs.length - 1
      previous = diffs[index]?.diffId
      ## Don't show a zero-length slider
      return unless diffs.length
      ## Draw slider
      @slider = new Slider @find('input'),
        #min: 0                 ## min and max not needed when using ticks
        #max: diffs.length-1
        #value: diffs.length-1  ## doesn't update, unlike setValue method below
        ticks: [0...diffs.length]
        ticks_snap_bounds: 999999999
        reversed: diffs.length == 1  ## put one tick at far right
        tooltip: 'always'
        tooltip_position: 'bottom'
        formatter: (i) ->
          if i of diffs
            formatDate(diffs[i].updated) + '\n' + diffs[i].updators.join ', '
          else
            i
      @slider.setValue index
      #@slider.off 'change'
      @slider.on 'change', (e) =>
        messageHistory.set @data._id, diffs[e.newValue]
      messageHistory.set @data._id, diffs[index]

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
  callbacks = {}
  called = 0
  ## Start all file uploads simultaneously.
  for file, i in files
    do (i) ->
      file.callback = (file2, done) ->
        ## Set up callback for when this file is completed.
        callbacks[i] = ->
          Meteor.call 'messageNew', group, message, null,
            file: file2.uniqueIdentifier
            finished: true
          , done
        ## But call all the callbacks in order by file, so that replies
        ## appear in the correct order.
        while callbacks[called]?
          callbacks[called]()
          called += 1
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
    file.callback = (file2, done) ->
      diff =
        file: file2.uniqueIdentifier
        finished: true
      ## Reset rotation angle on replace
      data = findMessage message
      if data.rotate
        diff.rotate = 0
      Meteor.call 'messageUpdate', message, diff, done
    file.group = group
    Files.resumable.addFile file, e

uploader 'messageReplace', 'replaceButton', 'replaceInput', replaceFiles

Template.messageAuthor.helpers
  formatAuthors: ->
    formatAuthors.call messageHistory.get(@_id) ? @

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
  #'click .threadPrivacyToggle': (e, t) ->
  #  e.preventDefault()
  #  e.stopPropagation()  ## prevent propagation to top-level dropdown
  #  console.log e.target
  #  $(e.target).dropdown 'toggle'
  'click .threadPrivacy': (e, t) ->
    e.preventDefault()
    e.stopPropagation()
    Meteor.call 'threadPrivacy', Template.parentData()._id,
      privacyOptionsByCode[e.target.getAttribute 'data-code'].list
    dropdownToggle e

Template.emojiButtons.helpers
  canReply: -> canPost @group, @_id
  emoji: -> Emoji.find group: $in: [wildGroup, @group]
  emojiMessages: ->
    tooltipUpdate()
    emojiReplies @
  who: -> (displayUser user for user in @who).join ', '

Template.emojiButtons.events
  'click .emojiAdd': (e, t) ->
    e.preventDefault()
    e.stopPropagation()
    message = t.data._id
    symbol = e.currentTarget.getAttribute 'data-symbol'
    #exists = EmojiMessages.findOne
    #  message: message
    #  creator: Meteor.user().username
    #  symbol: symbol
    #  deleted: false
    exists = Meteor.user().username in (t.data.emoji?[symbol] ? [])
    if exists
      console.warn "Attempt to add duplicate emoji '#{symbol}' to message #{message}"
    else
      Meteor.call 'emojiToggle', message, symbol
    dropdownToggle e

  'click .emojiToggle:not(.disabled)': (e, t) ->
    e.preventDefault()
    e.stopPropagation()
    tooltipHide t
    message = t.data._id
    symbol = e.currentTarget.getAttribute 'data-symbol'
    Meteor.call 'emojiToggle', message, symbol

Template.replyButtons.helpers
  canReply: -> canPost @group, @_id
  canPublicReply: -> 'public' in (@threadPrivacy ? ['public'])
  canPrivateReply: -> 'private' in (@threadPrivacy ? ['public'])

Template.tableOfContentsMessage.onRendered ->
  @autorun =>
    listener = messageDrag.call @, @find('a'), false, listener

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
  dragId = e.originalEvent.dataTransfer?.getData('application/coauthor-id')
  unless dragId
    url = e.originalEvent.dataTransfer?.getData 'text/plain'
    if url?
      url = parseCoauthorMessageUrl url
      if url?.hash
        dragId = url.hash[1..]
      else
        dragId = url?.message
  if index = e.target.getAttribute 'data-index'
    index = parseInt index
    dropId = e.target.getAttribute 'data-parent'
  else
    dropId = e.target.getAttribute 'data-id'
  if dragId and dropId
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
    "drop .beforeMessageDrop": dropOn

messageParent = (child, parent, index = null) ->
  return if child == parent  ## ignore trivial self-loop
  childMsg = findMessage(child) ? _id: child
  parentMsg = findMessage(parent) ? _id: parent
  oldParent = findMessageParent child
  oldIndex = oldParent?.children.indexOf child
  if parentMsg?._id == oldParent?._id
    ## Ignore drag to same place
    return if index == oldIndex or
      (not index? and oldIndex == oldParent.children.length - 1)
    ## If dragging within same parent to a later-numbered child,
    ## need to decrease index by 1 to account for loss of self.
    if index? and index > oldIndex
      index -= 1
      return if index == oldIndex
  Modal.show 'messageParentDialog',
    child: childMsg
    parent: parentMsg
    oldParent: oldParent
    index: index
    oldIndex: oldIndex

Template.messageParentDialog.onCreated ->
  unless @data.oldParent?
    if @data.child.group?
      @data.oldParent =
        isGroup: true
        group: @data.child.group
    else
      @data.oldParent =
        _id: null  # triggers unloaded view
  @parent = new ReactiveVar @data.parent
  #@index = new ReactiveVar @data.index

Template.messageParentDialog.helpers
  parent: -> Template.instance().parent.get()

Template.messageParentDialog.onRendered ->
  @autorun =>
    @messages = Messages.find {},
      fields:
        _id: true
        group: true
        title: true
        file: true
        creator: true
        children: true
    .fetch()
    byId = {}
    for msg in @messages
      byId[msg._id] = msg
    ## Remove descendants similar to descendantMessageIds, but using fetched.
    recurse = (id) ->
      msg = byId[id]
      return unless msg?
      delete byId[id]
      for child in msg.children
        recurse child
    recurse @data.child._id
    ## Show (messages from) other groups if superuser for this group
    acrossGroups = canSuper @data.child.group
    @messages =
      for msg in @messages when msg._id of byId and (
          acrossGroups or msg.group == @data.child.group)
        msg.text = "#{titleOrUntitled msg} by #{msg.creator} [#{msg._id}]"
        msg.html = "#{_.escape titleOrUntitled msg} <span class=\"author\"><i>by</i> #{_.escape msg.creator}</span> <span class=\"id\">[#{_.escape msg._id}]</span>"
        msg
    @messages.push
      text: "Group: #{@data.child.group}"
      html: "<i>Group</i>: #{@data.child.group}"
    if acrossGroups
      Groups.find
        name: $ne: @data.child.group
      , fields: name: true
      .forEach (group) =>
        @messages.push
          text: "Group: #{group.name}"
          html: "<i>Group</i>: #{group.name}"
      
  @$('.typeahead').typeahead
    hint: true
    highlight: true
    minLength: 1
  ,
    name: 'parent'
    limit: 50
    source: (q, callback) =>
      re = new RegExp (escapeRegExp q), 'i'
      callback(msg for msg in @messages when msg.text.match re)
    display: (msg) -> msg.text
    templates:
      suggestion: (msg) -> "<div>#{msg.html}</div>"
      notFound: '<i style="margin: 0ex 1em">No matching messages found.</i>'

Template.messageParentDialog.events
  "typeahead:autocomplete .parent, typeahead:cursorchange .parent, typeahead:select .parent, input .parent": (e, t) ->
    text = t.find('.tt-input').value
    if match = ///(?:^\s*|[\[/:])(#{idRegex})\]?\s*$///.exec text
      msg = findMessage(match[1]) ? {_id: match[1]}  # allow unknown message ID
      if e.type == 'input' and t.parent.get()?._id != match[1] and
         msg.creator?  # hand-typed new good message ID
        t.$('.typeahead').typeahead 'close'
      t.parent.set msg
    else if match = /^\s*Group:\s*(.*?)\s*$/i.exec text
      t.parent.set
        isGroup: true
        group: match[1]

  "click .messageParentButton": (e, t) ->
    e.preventDefault()
    e.stopPropagation()
    Modal.hide()
    parent = t.parent.get()
    if t.data.index? and t.data.parent == parent # unchanged from drag
      console.assert not parent.isGroup
      Meteor.call 'messageParent', t.data.child._id, t.data.parent._id, t.data.index
    else if parent.isGroup
      Meteor.call 'messageParent', t.data.child._id, null, parent.group
    else
      Meteor.call 'messageParent', t.data.child._id, parent._id

  "click .cancelButton": (e) ->
    e.preventDefault()
    e.stopPropagation()
    Modal.hide()

Template.groupOrMessage.helpers
  loadedMessage: -> @creator?
