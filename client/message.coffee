import React, {useCallback, useEffect, useLayoutEffect, useMemo, useRef, useState} from 'react'
import ReactDOM from 'react-dom'
import Dropdown from 'react-bootstrap/Dropdown'
import OverlayTrigger from 'react-bootstrap/OverlayTrigger'
import Tooltip from 'react-bootstrap/Tooltip'
import {useTracker} from 'meteor/react-meteor-data'
import {useInView} from 'react-intersection-observer'
import Blaze from 'meteor/gadicc:blaze-react-component'
import {useMediaQuery} from 'react-responsive'
import useEventListener from '@use-it/event-listener'

import {Credits} from './layout.coffee'
import {ErrorBoundary} from './ErrorBoundary'
import {FormatDate, formatDate} from './lib/date'
import {ignoreKey} from './keyboard'
import {MessageImage, imageTransform, messageRotate} from './MessageImage'
import {MessagePDF} from './MessagePDF'
import {TagEdit} from './TagEdit'
import {TagList} from './TagList'
import {TextTooltip} from './lib/tooltip'
import {UserInput} from './UserInput'
import {UserLink} from './UserLink'
import {resolveTheme} from './theme'
import {defaultHeight, emailless, messagePreviewDefault} from './settings.coffee'
import {forceImgReload} from './lib/forceImgReload'
import {useElementWidth} from './lib/resize'
import {setMigrateSafe, migrateWant} from './lib/migrate'
import {prefersReducedMotion, scrollBehavior} from './lib/scroll'
import {allEmoji} from '/lib/emoji'
import {availableFormats, formatBody, formatFile, formatFileDescription, formatTitleOrFilename, parseCoauthorAuthorUrl, parseCoauthorMessageUrl} from '/lib/formats'
import {ancestorMessages, descendantMessagesQuery, messageDiffsExpanded, messageNeighbors, sortedMessageReaders} from '/lib/messages'
import {autosubscribe, defaultNotificationsOn, messageSubscribers} from '/lib/notifications'
import {autopublish, defaultKeyboard, userKeyboard, themeEditor} from '/lib/settings'
import {escapeTag, sortTags} from '/lib/tags'

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

@routeMessage = ->
  Router.current()?.params?.message

export SubmessageHeader = React.memo ({message}) ->
  <>
    <MaybeRootHeader message={message}/>
    <Submessage message={message}/>
  </>
SubmessageHeader.displayName = 'SubmessageHeader'

Template.submessageHeader.helpers
  SubmessageHeader: -> SubmessageHeader
  message: -> @

Template.submessageHeaderNoChildren.helpers
  SubmessageHeader: -> SubmessageHeader
  messageNoChildren: -> Object.assign {}, @, children: []

export MaybeRootHeader = React.memo ({message}) ->
  return null unless message?.root?
  <ErrorBoundary>
    <RootHeader message={message}/>
  </ErrorBoundary>
MaybeRootHeader.displayName = 'MaybeRootHeader'

export RootHeader = React.memo ({message}) ->
  root = useTracker ->
    Messages.findOne message.root
  , [message.root]
  formattedTitle = useMemo ->
    return unless root?
    formatTitleOrFilename root,
      orUntitled: false
      bold: true
      id: message._id
  , [root, message._id]

  return null unless root?
  <div className="panel panel-default root" data-message={root._id}>
    <div className="panel-heading compact title">
      <div className="message-left-buttons push-down btn-group btn-group-xs">
        <a className="btn btn-info focusButton" aria-label="Focus" href={pathFor 'message', {group: root.group, message: root._id}}>
          <span className="fas fa-sign-in-alt" aria-hidden="true"/>
        </a>
      </div>
      <span className="space"/>
      <span className="title panel-title"
       dangerouslySetInnerHTML={__html: formattedTitle}/>
      <MessageTags message={root}/>
      <MessageLabels message={root}/>
    </div>
  </div>
RootHeader.displayName = 'RootHeader'

Template.messageBad.helpers
  message: -> Router.current().params.message

messageOrphans = (message) ->
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
  .fetch()

useChildren = (message, indexed) ->
  useTracker ->
    for childID, index in message.children
      child = Messages.findOne childID
      ## Use canSee to properly fake non-superuser mode.
      continue unless child? and canSee child #or routeHere child._id
      if indexed
        [child, index]
      else
        child
  , [message.children.join ',']  # depend on children IDs, not the array

authorCount = (field, group) ->
  authors =
    for username, count of Session.get field
      continue unless count
      user: findUsername(username) ? username: username
      count: count
  authors = _.sortBy authors, (author) -> userSortKey author.user
  authors = _.sortBy authors, (author) -> -author.count
  count = 0
  for author in authors
    <React.Fragment key={author.user.username}>
      {', ' if count++}
      <UserLink group={group} user={author.user}/>
      {" (#{author.count})"}
    </React.Fragment>

Template.message.helpers
  MessageID: -> MessageID

export MessageID = React.memo ({messageID}) ->
  {group, message} = useTracker ->
    group: routeGroup()
    message: Messages.findOne messageID
  , [messageID]
  <ErrorBoundary>
    {if message?.group
      if message.group == group
        <Message message={message}/>
      else if group == wildGroup
        Router.go 'message', {group: message.group, message: message._id}
        null
      else
        <Blaze template="mismatchedGroupMessage" _id={message._id} group={message.group}/>
    else
      <Blaze template="messageBad"/>
    }
  </ErrorBoundary>
MessageID.displayName = 'MessageID'

Message = React.memo ({message}) ->
  useEffect ->
    setTitle titleOrUntitled message
    undefined
  , [message.title]

  ## Scroll to message ID given in URL's initial hash.
  ## hashchange/popstate events are handled by autoscroll.coffee
  useEffect ->
    ## If we just followed a link, window.location will be stale; wait a tick.
    Meteor.defer ->
      scrollToMessage window.location.hash if window.location.hash.length > 1
    undefined
  , [message._id]

  ## Display table of contents according to whether screen is at least
  ## Bootstrap 3's "sm" size, but allow user to override.
  isScreenSm = useMediaQuery query: '(min-width: 768px)'
  [toc, setToc] = useState()
  useLayoutEffect ->
    setToc isScreenSm
  , [isScreenSm]
  onToc = (e) ->
    e.preventDefault()
    e.stopPropagation()
    setToc not toc
  useEventListener 'keydown', (e) ->
    return if ignoreKey e
    if e.key.toLowerCase() == 't'
      onToc e

  ## Set sticky column height to remaining height of screen:
  ## 100vh when stuck, and less when header is (partly) visible.
  stickyRef = useRef()
  stickyHeight = useCallback _.debounce(->
    return unless stickyRef.current?
    rect = stickyRef.current.getBoundingClientRect()
    stickyRef.current.style.height = "calc(100vh - #{rect.y}px)" if rect.height
    undefined
  , 100), []
  useEffect stickyHeight, [toc]  # initialize
  useEventListener 'resize', stickyHeight
  useEventListener 'scroll', stickyHeight

  <>
    <div className="hidden-print text-right toc-toggle">
      <OverlayTrigger placement="top" flip overlay={(props) ->
        <Tooltip {...props}>
          Click (or type <kbd>t</kbd>) to toggle the right sidebar
          listing all posts.  Click on post to scroll to that post;
          drag posts to re-order.
        </Tooltip>
      }>
        <a href="#" onClick={onToc}>
          {if toc
            <span className="fas fa-caret-down"/>
          else
            <span className="fas fa-caret-right"/>
          }
          {' Table of Contents'}
        </a>
      </OverlayTrigger>
    </div>
    <div className="row">
      <div className={if toc then "col-xs-9" else "col-xs-12"} role="main">
        <MaybeRootHeader message={message}/>
        <Submessage message={message}/>
        <MessageInfoBoxes message={message}/>
        <Credits/>
      </div>
      {if toc
        <div className="col-xs-3 hidden-print sticky-top"
        role="complementary" ref={stickyRef}>
          <TableOfContentsID messageID={message._id}/>
        </div>
      }
    </div>
  </>
Message.displayName = 'Message'

pinnedIndex = new ReactiveDict  # maps pinned message IDs to indices 1, 2, ...

MessageInfoBoxes = React.memo ({message}) ->
  orphans = useTracker ->
    messageOrphans message._id
  , [message._id]
  {authors, mentions} = useTracker ->
    authors: authorCount 'threadAuthors', message.group
    mentions: authorCount 'threadMentions', message.group
  , []
  subscribers = useTracker ->
    subscribers = messageSubscribers message._id,
      fields: username: true
    subscribed = {}
    for user in subscribers
      subscribed[user.username] = true
    users = sortedMessageReaders message._id
    unless users.length
      return '(none)'
    count = 0
    (for user in users
      if user.username of subscribed
        subtitle = 'Subscribed to email notifications'
        icon = <span className="fas fa-check"/> #text-success
      else
        icon = <span className="fas fa-times"/> #text-danger
        unless user.emails?[0]?
          subtitle = "No email address"
        else if not user.emails[0].verified
          subtitle = "Unverified email address" #{user.emails[0].address}"
        else if not (user.profile.notifications?.on ? defaultNotificationsOn)
          subtitle = "Notifications turned off"
        else if not autosubscribe message.group, user
          subtitle = "Autosubscribe turned off, and not explicitly subscribed to thread"
        else
          subtitle = "Explicitly unsubscribed from thread"
      subtitle = icon = undefined if emailless()
      if icon?
        icon = <>{icon}{' '}</>
      <React.Fragment key={user.username}>
        {', ' if count++}
        <UserLink group={message.group} user={user} subtitle={subtitle} prefix={icon}/>
      </React.Fragment>
    )
  , [message._id, message.group]
  pinnedMessages = useTracker ->
    pinnedIndex.clear()
    index = 1
    Messages.find $and: [
      descendantMessagesQuery message2root message
    ,
      group: message.group
      pinned: true
    ],
      sort: updated: 1
      fields:
        format: true
        title: true
        file: true
        updated: true
    .map (pinnedMessage) ->
      pinnedIndex.set pinnedMessage._id, index
      index: index++
      _id: pinnedMessage._id
      updated: formatDate pinnedMessage.updated
      formattedTitle: formatTitleOrFilename pinnedMessage, bold: true
  , [message._id, message.group, message.root]

  <>
    <div className="authors alert alert-info">
      {if authors.length
        <>
          <p>
            <b>Coauthors of visible messages in this thread:</b>
          </p>
          <p>{authors}</p>
        </>
      }
      {if authors.length and mentions.length
        <hr/>
      }
      {if mentions.length
        <>
          <p>
            <b>Users @mentioned in visible messages in this thread:</b>
          </p>
          <p>{mentions}</p>
        </>
      }
    </div>
    <div className="subscribers alert alert-success">
      <p>
        {if emailless()
          <b>Users who can read this message:</b>
        else
          <b>Users who can read this message, and whether they are subscribed to notifications:</b>
        }
      </p>
      <p>{subscribers}</p>
    </div>
    {if orphans.length
      <div className="orphans alert alert-warning">
        <p>
          <TextTooltip placement="right" title="Orphan subthreads are caused by someone deleting a message that has (undeleted) children, which become orphans.  You can move these orphans to a valid parent, or delete them, or ask the author or a superuser to undelete the original parent.">
            <b>{pluralize orphans.length, 'orphaned subthread'}:</b>
          </TextTooltip>
        </p>
        <p>
          {for orphan in orphans
            <Submessage key={orphan._id} message={orphan}/>
          }
        </p>
      </div>
    }
    {if pinnedMessages.length
      <div className="pinned alert alert-special">
        <p><b>Pinned messages in this thread:</b></p>
        <ul className="pinned">
          {for pinnedMessage in pinnedMessages
            <li key={pinnedMessage._id}>
              <a href={pathFor 'message',
                group: message.group
                message: pinnedMessage._id
              }>
                <span className="fas fa-thumbtack"/>
                {pinnedMessage.index}
                {' '}
                <span className="title"
                 dangerouslySetInnerHTML={__html: pinnedMessage.formattedTitle}/>
                {' '}
                (last updated {pinnedMessage.updated})
              </a>
            </li>
          }
        </ul>
      </div>
    }
  </>
MessageInfoBoxes.displayName = 'MessageInfoBoxes'

editingMessage = (message, user = Meteor.user()) ->
  user? and user.username in (message.editing ? [])

idle = 1000   ## one second

export messageClass = ->
  if @deleted
    'deleted'
  else if not @published
    'unpublished'
  else if @private
    'private'
  else if @minimized
    'minimized'
  else if @pinned
    'pinned'
  else
    'published'

messageRaw = new ReactiveDict 'messageRaw'
export messageFolded = new ReactiveDict 'messageFolded'
defaultFolded = new ReactiveDict
messageHistory = new ReactiveDict
messageHistoryAll = new ReactiveDict
messageKeyboard = new ReactiveDict
messagePreview = new ReactiveDict
## The following helpers should only be called when editing.
messagePreviewGet = (messageID) ->
  messagePreview.get(messageID) ? messagePreviewDefault()
messagePreviewSet = (messageID, change) ->
  messagePreview.set messageID, change messagePreviewGet messageID

## Authors and @mentions tracked throughout Submessage views
threadAuthors = {}
threadMentions = {}

imageRefCount = new ReactiveDict
imageInternalRefCount = new ReactiveDict
id2dom = {}
scrollToLater = null
fileQuery = null
fileQueries = {}

checkImage = (id) ->
  if id2dom[id]? or imageRefCount.get id
    return if id of fileQueries
    fileQueries[id] = true
  else
    return unless id of fileQueries
    delete fileQueries[id]
  updateFileQuery()
updateFileQuery = _.debounce ->
  fileQuery?.stop()
  fileQuery = Messages.find
    _id: $in: _.keys fileQueries
  ,
    fields: file: true
  .observeChanges
    added: (id, fields) ->
      #console.log "#{id} added:", fields
      return unless fileQueries[id]?
      fileQueries[id] = fields.file
    changed: (id, fields) ->
      #console.log "#{id} changed:", fields
      return unless fileQueries[id]?
      if fields.file? and fileQueries[id].file != fields.file
        ## setTimeout to wait for React to finish rendering
        setTimeout (-> forceImgReload urlToFile id), 1000
        fileQueries[id].file = fields.file
, 100

messageOnDragStart = (message) -> (e) ->
  #url = "coauthor:#{message._id}"
  url = urlFor 'message',
    group: message.group
    message: message._id
  e.dataTransfer.effectAllowed = 'linkMove'
  e.dataTransfer.setData 'text/plain', url
  e.dataTransfer.setData 'application/coauthor-id', message._id
  e.dataTransfer.setData 'application/coauthor-type',
    if message.file
      fileType message.file
    else
      'message'

## A message is "naturally" folded if it is flagged as minimized or deleted.
## It still will be default-folded if it's an image referenced in another
## message that is not naturally folded.
export naturallyFolded = (message) -> message.minimized or message.deleted

export scrollToMessage = (id) ->
  id = id[1..] if id[0] == '#'
  if (dom = id2dom[id])?
    scrollToLater = null
    $('html, body').animate
      scrollTop: Math.max 0, $(dom).offset().top - 15
    , (if prefersReducedMotion() then 0 else 200)
    , 'swing', ->
      ## Focus on title edit box when scrolling to message being edited.
      ## We'd like to use `$(dom).find('input.title')`
      ## but want to exclude children.
      dom.firstChild?.querySelector('input.title')?.focus()
  else
    scrollToLater = id
    ## Unfold ancestors of clicked message so that it becomes visible.
    for ancestor from ancestorMessages id
      messageFolded.set ancestor._id, false
  ## Also unfold message itself, because you probably want to see it.
  messageFolded.set id, false

routeHere = (id) ->
  id? and Router.current().route?.getName() == 'message' and
  Router.current().params?.message == id

Template.readMessage.helpers
  ReadMessage: -> ReadMessage
  messageNoChildren: -> Object.assign {}, @, children: []

export ReadMessage = ({message}) ->
  <>
    <MaybeRootHeader message={message}/>
    <Submessage message={message} read={true}/>
  </>
ReadMessage.displayName = 'ReadMessage'

Template.submessage.helpers
  Submessage: -> Submessage
  message: -> @

export MessageIcons = React.memo ({message, editors}) ->
  editors = useTracker ->
    (displayUser editor for editor in message.editing ? []).join ', '
  , [message.editing?.join ',']
  pinIndex = useTracker ->
    pinnedIndex.get message._id
  , [message._id]

  <>
    {if editors
      <>
        <TextTooltip title={"Being edited by #{editors}"}>
          <span className="fas fa-edit"/>
        </TextTooltip>
        {' '}
      </>
    }
    {if message.pinned
      <>
        <span className="fas fa-thumbtack"/>
        {pinIndex}
        {' '}
      </>
    }
    {if message.file
      <>
        <span className="fas fa-paperclip"/>
        {' '}
      </>
    }
  </>

export MessageTags = React.memo ({message, noLink}) ->
  <span className="messageTags">
    <TagList tags={sortTags message.tags} group={message.group} noLink={noLink}/>
  </span>
MessageTags.displayName = 'MessageTags'

export MessageLabels = React.memo ({message}) ->
  <span className="messageLabels">
    {if message.deleted
      <>
        {' '}
        <span className="label label-danger">Deleted</span>
      </>
    }
    {unless message.published
      <>
        {' '}
        <span className="label label-warning">Unpublished</span>
      </>
    }
    {if message.private
      <>
        {' '}
        <span className="label label-info">Private</span>
      </>
    }
    {if message.minimized
      <>
        {' '}
        <span className="label label-success">Minimized</span>
      </>
    }
  </span>
MessageLabels.displayName = 'MessageLabels'

export MessageNeighborsOrParent = React.memo ({message}) ->
  <ErrorBoundary>
    {if message.root?
      <MessageParent message={message}/>
    else
      <MessageNeighbors message={message}/>
    }
  </ErrorBoundary>
MessageNeighborsOrParent.displayName = 'MessageNeighborsOrParent'

MessageNeighbors = React.memo ({message}) ->
  neighbors = useTracker ->
    messageNeighbors message
  , [message]
  renderNeighbor = (neighbor, icon, label) ->
    if neighbor?
      url = pathFor 'message',
        group: neighbor.group
        message: neighbor._id
      <OverlayTrigger placement="top" flip overlay={(props) ->
        <Tooltip {...props}>
          <div dangerouslySetInnerHTML={__html:
            formatTitleOrFilename neighbor}/>
        </Tooltip>
      }>
        <a className="btn btn-info" href={url}>
          <span className="fas fa-#{icon}" aria-label={label}/>
        </a>
      </OverlayTrigger>
    else
      <a className="btn btn-info disabled">
        <span className="fas fa-#{icon}" aria-hidden="true"/>
      </a>
  <>
    {renderNeighbor neighbors.prev, 'backward', 'Previous'}
    {renderNeighbor neighbors.next, 'forward', 'Next'}
  </>
MessageNeighbors.displayName = 'MessageNeighbors'

export MessageParent = React.memo ({message}) ->
  parent = useTracker ->
    findMessageParent message._id
  , [message._id]
  return null unless parent?
  <TextTooltip title={parent.title}>
    <a className="btn btn-info" href="#{pathFor 'message', {group: parent.group, message: parent._id}}#">
      <span className="fas fa-chevron-up" aria-label="Parent"/>
    </a>
  </TextTooltip>
MessageParent.displayName = 'MessageParent'

export MessageEditor = React.memo ({message, setEditBody, tabindex}) ->
  messageID = message._id
  [editor, setEditor] = useState()
  useEffect ->
    return unless editor?
    switch sharejsEditor
      when 'cm'
        editor.getInputField().setAttribute 'tabindex', tabindex
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
        ## Embed files as images if dragged to beginning of line or after
        ## a space or table separator (| for Markdown, & for LaTeX).
        useImage = (pos) ->
          pos.ch == 0 or
          /^[\s|&]$/.test editor.getRange
            line: pos.line
            ch: pos.ch - 1
          , pos
        embedFile = (type, id, pos) ->
          if useImage pos
            switch type
              when 'image', 'video', 'pdf'
                switch findMessage(messageID)?.format
                  when 'markdown'
                    return "![](coauthor:#{id})"
                  when 'latex'
                    return "\\includegraphics{coauthor:#{id}}"
                  else #when 'html'
                    return """<img src="coauthor:#{id}">"""
              #when 'video'
              #  """<video controls><source src="coauthor:#{id}"></video>"""
          "coauthor:#{id}"
        editor.display.dragFunctions.drop = (e) ->
          text = e.dataTransfer?.getData 'text'
          id = e.dataTransfer?.getData 'application/coauthor-id'
          username = e.dataTransfer?.getData 'application/coauthor-username'
          type = e.dataTransfer?.getData 'application/coauthor-type'
          if username
            replacement = "@#{username}"
          else if id
            pos = editor.coordsChar
              left: e.x
              top: e.y
            replacement = embedFile type, id, pos
          else if (match = parseCoauthorMessageUrl text, true)?
            replacement = "coauthor:#{match.message}#{match.hash}"
          else if (match = parseCoauthorAuthorUrl text)?
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
            if (match = parseCoauthorMessageUrl text, true)?
              paste = ["coauthor:#{match.message}#{match.hash}"]
              if not match.hash
                msg = findMessage match.message
                if msg?.file? and type = fileType msg.file
                  paste = [embedFile type, match.message, editor.getCursor()]
            else if (match = parseCoauthorAuthorUrl text)?
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
        editor.textInput.getElement().setAttribute 'tabindex', tabindex
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
      _.debounce => setEditBody editor.getDoc().getValue()
      , 100
  , [editor]
  useTracker ->
    return unless editor?
    preview = messagePreviewGet messageID
    editor.setSize null, preview.height
  , [messageID, editor]
  useEffect ->
    return unless editor?
    editorMode editor, message.format
    undefined
  , [editor, message.format]
  useTracker ->
    return unless editor?
    editorKeyboard editor, messageKeyboard.get(messageID) ? userKeyboard()
  , [editor, messageID]
  <MessageEditor_ messageID={messageID} setEditor={setEditor} tabindex={tabindex}/>
MessageEditor.displayName = 'MessageEditor'

export MessageEditor_ = React.memo ({messageID, setEditor, tabindex}) ->
  <Blaze template="sharejs" docid={messageID}
   onRender={-> (editor) -> setEditor editor}
   onError={-> (error) ->
     if error == 'Document does not exist'  # Server restarted
       @disconnect() # => preserve local edits (otherwise rejects everything)
   }/>
MessageEditor_.displayName = 'MessageEditor_'

export BelowEditor = React.memo ({message, preview, safeToStopEditing, editStopping}) ->
  migrated = useTracker ->
    migrateWant.get()
  , []
  myUsername = useTracker ->
    Meteor.user()?.username
  , []
  coauthorMap = useTracker ->
    map = {}
    for coauthor in message.coauthors
      map[coauthor] =
        canRemove: canCoauthorsMod message, $pull: [coauthor]
    map
  , [message.coauthors.join ' ']
  #newEditors = useTracker ->
  #  editor for editor in message.editing when editor not of coauthorMap
  #, [message.editing?.join(' '), coauthorMap]
  showAccess = message.access?.length or message.private
  accessMap = useMemo ->
    map = {}
    map[username] = true for username in message.access ? []
    map
  , [message.access?.join ' ']
  mentions = useTracker ->
    atMentions message if showAccess
  , [showAccess, message.title, message.body]
  suggestions = useMemo ->
    return unless showAccess
    map = {}
    for username in mentions
      unless username of coauthorMap or username of accessMap
        map[username] = true
    _.keys map
  , [showAccess, mentions, coauthorMap, accessMap]
  changedHeight = useTracker ->
    height = messagePreviewGet(message._id).height
    height? and height != (Meteor.user()?.profile?.preview?.height ? defaultHeight)
  , [message._id]

  onAddCoauthor = (coauthor) ->
    Meteor.call 'messageUpdate', message._id,
      coauthors: $addToSet: [coauthor.username]
  onRemoveCoauthor = (e) ->
    e.preventDefault()
    Meteor.call 'messageUpdate', message._id,
      coauthors: $pull: [e.target.dataset.username]
  onAddAccess = (user) ->
    Meteor.call 'messageUpdate', message._id,
      access: $addToSet: [user.username]
  onAddAccessButton = (e) ->
    Meteor.call 'messageUpdate', message._id,
      access: $addToSet: [e.target.dataset.username]
  onRemoveAccess = (e) ->
    e.preventDefault()
    Meteor.call 'messageUpdate', message._id,
      access: $pull: [e.target.dataset.username]
  onTogglePreview = (e) ->
    e.preventDefault()
    e.stopPropagation()
    messagePreviewSet message._id, (current) -> Object.assign {}, current,
      on: not current.on
  onSideBySidePreview = (e) ->
    e.preventDefault()
    e.stopPropagation()
    messagePreviewSet message._id, (current) -> Object.assign {}, current,
      sideBySide: not current.sideBySide
  onResizer = (start) ->
    $(start.target).addClass 'active'
    oldHeight = messagePreviewGet(message._id).height
    $(document).mousemove mover = (move) ->
      messagePreviewSet message._id, (preview) -> _.extend {}, preview,
        height: Math.max 100, oldHeight + move.clientY - start.clientY
    cancel = (e) ->
      $(start.target).removeClass 'active'
      $(document).off 'mousemove', mover
      $(document).off 'mouseup', cancel
      $(document).off 'mouseleave', cancel
    $(document).mouseup cancel
    $(document).mouseleave cancel
  onSetHeight = (e) ->
    e.preventDefault()
    e.stopPropagation()
    Meteor.users.update Meteor.userId(),
      $set: "profile.preview.height": messagePreviewGet(message._id)?.height

  <>
    <div className="belowEditor clearfix">
      <div className="pull-right btn-group">
        {if changedHeight
          <button className="btn btn-warning setHeight" onClick={onSetHeight}>Set Default Height</button>
        }
        {if preview.on
          <>
            {if preview.sideBySide
              <button className="btn btn-default sideBySidePreview" onClick={onSideBySidePreview}>Top-Bottom</button>
            else
              <button className="btn btn-default sideBySidePreview" onClick={onSideBySidePreview}>Side-by-Side</button>
            }
            <button className="btn btn-default togglePreview" onClick={onTogglePreview}>No Preview</button>
          </>
        else
          <button className="btn btn-default togglePreview" onClick={onTogglePreview}>Preview</button>
        }
      </div>
      <div className="alert alert-#{if safeToStopEditing then 'success' else 'danger'} below-editor-alert">
        {if safeToStopEditing
          'All changes saved.'
        else if migrated
          <>
            <b>SERVER HAS RESET</b>. Please copy this message's contents to your clipboard and a temporary file, and then reload the page.
          </>
        else if editStopping
          'Unsaved changes. Stopping editing once saved...'
        else
          'Unsaved changes. Saving...'
        }
        {
          others = _.without message.editing, myUsername
          if others.length
            count = 0
            <span className="otherEditors">
              {' Editing with '}
              {for other in others
                <React.Fragment key={other}>
                  {', ' if count++}
                  <UserLink group={message.group} username={other}/>
                </React.Fragment>
              }
              {'.'}
            </span>
        }
      </div>
      <div className="alert alert-info below-editor-alert coauthors-alert">
        <span className="upper-strut">&#8203;</span>
        <TextTooltip title="List everyone who worked on this message or its ideas, who might be considered a coauthor on an eventual paper about it. Coauthors can always access the message (unless removed) and help write, even at the same time. Editing a message automatically adds you as a coauthor.">
          <span className="text-help">Coauthors:</span>
        </TextTooltip>
        {' '}
        {
        count = 0
        for coauthor in message.coauthors #.concat newEditors
          <React.Fragment key={coauthor}>
            {', ' if count++}
            <UserLink group={message.group} username={coauthor}
             subtitle={messageAuthorSubtitle message, coauthor}/>
            {if coauthorMap[coauthor]?.canRemove and message.coauthors.length > 1
              <>
                {' '}
                <a href="#" onClick={onRemoveCoauthor} className="removeCoauthor">
                  <span className="fas fa-times-circle danger-close"
                  aria-label="Remove" data-username={coauthor}/>
                </a>
              </>
            }
          </React.Fragment>
        }
        {', ' if count}
        <UserInput group={message.group}
         omit={(user) -> user.username of coauthorMap}
         placeholder="who're you working with?" onSelect={onAddCoauthor}/>
        {if showAccess
          <div className="access">
            <TextTooltip title="List anyone you want to see your private message and (by default) all its replies, or remove anyone you don't want to see this message. No need to list coauthors here: they can always access the message, even if it's deleted or unpublished.">
              <span className="text-help">
                Additional access
                {" if undeleted" if message.deleted}
                {" and" if message.deleted and not message.published}
                {" once published" unless message.published}
                :
              </span>
            </TextTooltip>
            {' '}
            {
            count = 0
            for user in message.access ? []
              <React.Fragment key={user}>
                {', ' if count++}
                <UserLink group={message.group} username={user}/>
                {if true ### eslint-disable-line coffee/no-constant-condition ###
                  <>
                    {' '}
                    <a href="#" onClick={onRemoveAccess}
                     className="removeAccess">
                      <span className="fas fa-times-circle danger-close"
                      aria-label="Remove" data-username={user}/>
                    </a>
                  </>
                }
              </React.Fragment>
            }
            {', ' if count}
            <UserInput group={message.group}
             omit={(user) -> user.username of coauthorMap or
                             user.username of accessMap}
             placeholder="add user access" onSelect={onAddAccess}/>
            {for suggestion in suggestions
              <React.Fragment key={suggestion}>
                {', '}
                <TextTooltip title="This user is @mentioned but doesn't have explicit access. Did you mean to list them? Click if so!">
                  <button className="btn btn-warning btn-sm"
                   data-username={suggestion} onClick={onAddAccessButton}>
                    <span className="fas fa-plus" aria-hidden="true"/>
                    {' ' + suggestion}
                  </button>
                </TextTooltip>
              </React.Fragment>
            }
          </div>
        }
      </div>
    </div>
    <div className="resizer" onMouseDown={onResizer}/>
  </>
BelowEditor.displayName = 'BelowEditor'

panelClass =
  deleted: 'panel-danger'
  unpublished: 'panel-warning'
  private: 'panel-info'
  minimized: 'panel-success'
  pinned: 'panel-special'
  published: 'panel-primary'
messagePanelClass = (message, editing) ->
  classes = []
  classes.push mclass = messageClass.call message
  classes.push panelClass[mclass]
  if editing
    classes.push 'editing'
  classes.join ' '

Template.registerHelper 'creator', ->
  displayUser @creator

export KeyboardSelector = React.memo ({messageID, tabindex}) ->
  keyboard = useTracker ->
    messageKeyboard.get(messageID) ? userKeyboard()
  , [messageID]

  onClick = (e) ->
    e.preventDefault()
    messageKeyboard.set messageID, e.target.getAttribute 'data-keyboard'

  <Dropdown className="btn-group">
    <Dropdown.Toggle variant="default" tabIndex={tabindex}>
      {"#{capitalize keyboard} "}
      <span className="caret"/>
    </Dropdown.Toggle>
    <Dropdown.Menu>
      {for k in ['normal', 'vim', 'emacs']
        <li key={k} className="editorKeyboard #{if keyboard == k then 'active' else ''}">
          <Dropdown.Item href="#" data-keyboard={k} onClick={onClick}>
            {capitalize k}
          </Dropdown.Item>
        </li>
      }
    </Dropdown.Menu>
  </Dropdown>
KeyboardSelector.displayName = 'KeyboardSelector'

export FormatSelector = React.memo ({messageID, format, tabindex}) ->
  format ?= defaultFormat

  onClick = (e) ->
    e.preventDefault()
    Meteor.call 'messageUpdate', messageID,
      format: e.target.getAttribute 'data-format'

  <Dropdown className="btn-group">
    <Dropdown.Toggle variant="default" tabIndex={tabindex}>
      {"#{capitalize format} "}
      <span className="caret"/>
    </Dropdown.Toggle>
    <Dropdown.Menu>
      {for f in availableFormats
        <li key={f} className="editorFormat #{if format == f then 'active' else ''}">
          <Dropdown.Item href="#" data-format={f} onClick={onClick}>
            {capitalize f}
          </Dropdown.Item>
        </li>
      }
    </Dropdown.Menu>
  </Dropdown>
FormatSelector.displayName = 'FormatSelector'

# Still needed for Settings
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

import 'bootstrap-slider/dist/css/bootstrap-slider.min.css'

Slider = null  # will become default import of 'bootstrap-slider' NPM package
MessageHistory = React.memo ({message}) ->
  ready = useTracker ->
    Meteor.subscribe 'messages.diff', message._id
    .ready()
  , [message._id]
  input = useRef()
  {diffs, index} = useTracker ->
    unless Slider?
      Session.set 'SliderLoading', true
      Session.get 'SliderLoading'  # rerun tracker once Slider loaded
      import('bootstrap-slider').then (imported) ->
        Slider = imported.default
        Session.set 'SliderLoading', false
      return {}
    previous = messageHistory.get(message._id)?.diffId
    diffs = messageDiffsExpanded message
    ## Restrict to finished diffs if requested, preserving last chosen diff
    index = -1
    unless messageHistoryAll.get message._id
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
    {diffs, index}
  , [message._id, message.creator, message.created]
  useEffect ->
    ## Don't show a zero-length slider
    return unless diffs?.length
    ## Draw slider
    slider = new Slider input.current,
      #min: 0                 ## min and max not needed when using ticks
      #max: diffs.length-1
      #value: diffs.length-1  ## doesn't update, unlike setValue method below
      ticks: [0...diffs.length]
      ticks_snap_bounds: 999999999
      reversed: diffs.length == 1  ## put one tick at far right
      tooltip: 'always'
      tooltip_position: 'bottom'
      preventOverflow: true
      formatter: (i) ->
        if i of diffs
          formatDate(diffs[i].updated) + '\n' + diffs[i].updators.join ', '
        else
          i
    slider.setValue index
    messageHistory.set message._id, diffs[index]
    slider.on 'change', (e) ->
      messageHistory.set message._id, diffs[e.newValue]
    -> slider.destroy()
  , [diffs, index]

  <div className="historySlider">
    <input type="text" ref={input}/>
    {unless ready
      <Blaze template="loading"/>
    }
  </div>
MessageHistory.displayName = 'MessageHistory'

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

export ThreadPrivacy = React.memo ({message, tabindex}) ->
  onPrivacy = (e) ->
    e.preventDefault()
    Meteor.call 'threadPrivacy', message._id,
      privacyOptionsByCode[e.target.getAttribute 'data-code'].list

  <Dropdown className="btn-group">
    <Dropdown.Toggle variant="warning" tabIndex={tabindex}>
      {"Thread Privacy "}
      <span className="caret"/>
    </Dropdown.Toggle>
    <Dropdown.Menu>
      {for privacy in privacyOptions
        active = _.isEqual _.sortBy(privacy.list),
                           _.sortBy(message.threadPrivacy ? ['public'])
        <li key={privacy.code} className="threadPrivacy #{if active then 'active' else ''}">
          <Dropdown.Item href="#" data-code={privacy.code} onClick={onPrivacy}>
            {privacy.display}
          </Dropdown.Item>
        </li>
      }
    </Dropdown.Menu>
  </Dropdown>
ThreadPrivacy.displayName = 'ThreadPrivacy'

export EmojiButtons = React.memo ({message, can}) ->
  emojis = useTracker ->
    allEmoji message.group
  , [message.group]
  ## Variation of lib/emoji.coffee's `emojiReplies`:
  replies = useTracker ->
    return [] unless message.emoji?
    for emoji in emojis  # match sort order of Emoji list
      usernames = message.emoji[emoji.symbol]
      continue unless usernames?.length
      who = (findUsername(username) ? username: username for username in usernames)
      who = _.sortBy who, userSortKey
      who = (displayUser user for user in who).join ', '
      Object.assign {}, emoji,
        who: who
        me: Meteor.user()?.username in usernames
        count: usernames.length
  , [message.emoji, emojis]
  [showTooltip, setShowTooltip] = useState false

  onEmojiAdd = (e) ->
    symbol = e.currentTarget.getAttribute 'data-symbol'
    #exists = EmojiMessages.findOne
    #  message: message._id
    #  creator: Meteor.user().username
    #  symbol: symbol
    #  deleted: false
    exists = Meteor.user().username in (message.emoji?[symbol] ? [])
    if exists
      console.warn "Attempt to add duplicate emoji '#{symbol}' to message #{message}"
    else
      Meteor.call 'emojiToggle', message._id, symbol
    setTimeout ->
      setShowTooltip false
    , 0  # hide tooltip after it gets focus from menu close
  onEmojiToggle = (e) ->
    symbol = e.currentTarget.getAttribute 'data-symbol'
    Meteor.call 'emojiToggle', message._id, symbol

  <div className="btn-group pull-left emojiButtons">
    {if can.reply
      <>
        {if emojis.length
          <Dropdown className="btn-group">
            <TextTooltip title="Add emoji response"
             show={showTooltip} onToggle={setShowTooltip}>
              <Dropdown.Toggle variant="default">
                <span className="fas fa-plus emoji-plus" aria-hidden="true"/>
                {' '}
                <span className="far fa-smile emoji-face" aria-hidden="true"/>
              </Dropdown.Toggle>
            </TextTooltip>
            <Dropdown.Menu className="emojiMenu">
              {for emoji in emojis
                <li key={emoji.symbol}>
                  <TextTooltip placement="bottom" title={emoji.description}>
                    <Dropdown.Item className="emojiAdd" href="#" data-symbol={emoji.symbol} onClick={onEmojiAdd}>
                      <span className="fas fa-#{emoji.symbol} #{emoji.class}"/>
                    </Dropdown.Item>
                  </TextTooltip>
                </li>
              }
            </Dropdown.Menu>
          </Dropdown>
        }
        {for reply in replies
          <TextTooltip key={reply.symbol} placement="bottom" title={reply.who}>
            <button className="btn btn-default #{if reply.me then 'my-emoji' else ''} emojiToggle" data-symbol={reply.symbol} onClick={onEmojiToggle}>
              <span className="fas fa-#{reply.symbol} #{reply.class}"/>
              {' '}
              <span>{reply.count}</span>
            </button>
          </TextTooltip>
        }
      </>
    else
      for reply in replies
        <TextTooltip key={reply.symbol} placement="bottom" title={reply.who}>
          <button className="btn btn-default #{if reply.me then 'my-emoji' else ''} emojiToggle disabled" data-symbol={reply.symbol}>
            <span className="fas fa-#{reply.symbol} #{reply.class}"/>
            {' '}
            <span>{reply.count}</span>
          </button>
        </TextTooltip>
    }
  </div>
EmojiButtons.displayName = 'EmojiButtons'

export uploaderProps = (callback, inputRef) ->
  buttonProps:
    onClick: (e) ->
      e.preventDefault()
      e.stopPropagation()
      inputRef.current.click()
  dropProps:
    onDragEnter: (e) ->
      e.preventDefault()
      e.stopPropagation()
    onDragOver: (e) ->
      e.preventDefault()
      e.stopPropagation()
    onDrop: (e) ->
      e.preventDefault()
      e.stopPropagation()
      callback e.dataTransfer.files, e
  inputProps:
    onInput: (e) ->
      callback e.target.files, e

export ReplyButtons = React.memo ({message, prefix}) ->
  attachInput = useRef()
  defaultPublished = useTracker ->
    autopublish()
  , []
  ## If parent is unpublished or deleted, inherit that state by default
  ## (in the former case, overriding autopublish setting).
  defaultPublished and= Boolean message.published
  defaultDeleted = Boolean message.deleted
  adjectives = []
  adjectives.push 'unpublished' unless defaultPublished
  adjectives.push 'deleted' if defaultDeleted
  adjectives.push 'private' if message.private
  adjectives = adjectives.join ' '
  adjectives += ' ' if adjectives
  once = []
  once.push 'published' unless defaultPublished
  once.push 'undeleted' if defaultDeleted
  if once.length
    once = " (once #{once.join ' and '})"
  else
    once = ''
  defaultVariant =
    if defaultPublished
      if message.private
        'info'
      else
        'default'
    else
      'warning'
  unless defaultPublished
    prefix ?= 'Unpublished '

  onReply = (e) ->
    e.preventDefault()
    e.stopPropagation()
    return unless canReply message
    reply = {}
    switch e.currentTarget.getAttribute 'data-privacy'
      when 'public'
        reply.private = false
      when 'private'
        reply.private = true
    switch e.currentTarget.getAttribute 'data-published'
      when 'false'
        reply.published = false
      when 'true'
        reply.published = true
      else
        reply.published = defaultPublished
    reply.deleted = defaultDeleted
    Meteor.call 'messageNew', message.group, message._id, null, reply, (error, result) ->
      if error
        console.error error
      else if result
        Meteor.call 'messageEditStart', result, (error2, result2) ->
          scrollToMessage result
          #Router.go 'message', {group: group, message: result}
      else
        console.error "messageNew did not return message ID -- not authorized?"
  attachFiles = (files, e) ->
    callbacks = {}
    called = 0
    ## Start all file uploads simultaneously.
    for file, i in files
      do (i) ->
        file.callback = (file2, done) ->
          ## Set up callback for when this file is completed.
          callbacks[i] = ->
            Meteor.call 'messageNew', message.group, message._id, null,
              file: file2.uniqueIdentifier
              deleted: defaultDeleted
              published: defaultPublished
              finished: true
            , done
          ## But call all the callbacks in order by file, so that replies
          ## appear in the correct order.
          while callbacks[called]?
            callbacks[called]()
            called += 1
      file.metadata =
        group: message.group
        root: message2root message
      Files.resumable.addFile file, e
  {buttonProps, dropProps, inputProps} = uploaderProps attachFiles, attachInput

  threadPrivacy = message.threadPrivacy ? ['public']
  publicReply = 'public' in threadPrivacy
  privateReply = 'private' in threadPrivacy

  <Dropdown className="message-reply-buttons btn-group pull-right">
    <Dropdown.Toggle variant="default" {...dropProps}>
      {"Reply/Attach "}
      <span className="caret"/>
    </Dropdown.Toggle>
    <Dropdown.Menu align="right" className="buttonMenu replyMenu">
      {if publicReply and not privateReply
        # normal reply, not necessarily public
        if message.private
          <li>
            <TextTooltip placement="left" title="A reply to a private message will be private but automatically start accessible to the same users (once they are published and not deleted). You can modify that access when editing the reply. Access does not stay synchronized, so if you later modify the parent's access, consider modifying the child too.">
              <Dropdown.Item href="#" onClick={onReply}>
                <button className="btn btn-#{defaultVariant} btn-block replyButton">
                  {prefix}
                  Reply
                </button>
              </Dropdown.Item>
            </TextTooltip>
          </li>
        else
          <li>
            <TextTooltip placement="left" title="Start a new #{adjectives}child message of this one, #{if defaultPublished then 'immediately ' else ''}visible to everyone in this thread#{once}.">
              <Dropdown.Item href="#" onClick={onReply}>
                <button className="btn btn-#{defaultVariant} btn-block replyButton">
                  {prefix}
                  Reply
                </button>
              </Dropdown.Item>
            </TextTooltip>
          </li>
      else
        <>
          {if publicReply
            <li>
              <TextTooltip placement="left" title="Start a new #{adjectives}child message of this one, visible to everyone in this thread#{once}.">
                <Dropdown.Item href="#" data-privacy="public" onClick={onReply}>
                  <button className="btn btn-#{defaultVariant} btn-block replyButton">
                    {prefix}
                    Public Reply
                  </button>
                </Dropdown.Item>
              </TextTooltip>
            </li>
          }
          {if privateReply
            <li>
              <TextTooltip placement="left" title="Start a new #{adjectives}child message of this one, visible only to coauthors and those explicitly given access#{once}, initially set to coauthors of the message you're replying to.">
                <Dropdown.Item href="#" data-privacy="private" onClick={onReply}>
                  <button className="btn btn-info btn-block replyButton">
                    {prefix}
                    Private Reply
                  </button>
                </Dropdown.Item>
              </TextTooltip>
            </li>
          }
        </>
      }
      <li>
        <Dropdown.Item href="#" {...buttonProps} {...dropProps}>
          <TextTooltip placement="left" title="Start a new #{adjectives}child message of this one that contains a single file attachment (or one message for each file, if you select multiple files; you can also drag files onto the Reply button). You can then edit the title and body of the file like a regular message.">
            <button className="btn btn-#{defaultVariant} btn-block">
              Reply with Attached File
            </button>
          </TextTooltip>
        </Dropdown.Item>
      </li>
      {
      ## Offer second (un)published option only if parent published;
      ## if parent unpublisehd, then we only offer unpublished above.
      if message.published
        <li>
          <Dropdown.Item href="#" data-published="#{not defaultPublished}" onClick={onReply}>
            {if defaultPublished
              <TextTooltip placement="left" title="Start a new #{adjectives}child message of this one that starts in the unpublished state, so it will become generally visible only when you select Action / Publish.">
                <button className="btn btn-warning btn-block">
                  Unpublished Reply
                </button>
              </TextTooltip>
            else
              <TextTooltip placement="left" title="Start a new #{adjectives}child message of this one that starts in the published state, so everyone in this thread can see it immediately#{if defaultDeleted then ' (once undeleted)' else ''}.">
                <button className="btn btn-success btn-block">
                  {prefix unless prefix == 'Unpublished '}
                  Published Reply
                </button>
              </TextTooltip>
            }
          </Dropdown.Item>
        </li>
      }
    </Dropdown.Menu>
    <input className="attachInput" type="file" multiple ref={attachInput}
     {...inputProps}/>
  </Dropdown>
ReplyButtons.displayName = 'ReplyButtons'

export MessageReplace = React.memo ({message, tabindex}) ->
  replaceInput = useRef()

  replaceFiles = (files, e, t) ->
    if files.length != 1
      console.error "Attempt to replace #{message._id} with #{files.length} files -- expected 1"
    else
      file = files[0]
      file.callback = (file2, done) ->
        diff =
          file: file2.uniqueIdentifier
          finished: true
        ## Reset rotation angle on replace
        data = findMessage message._id
        if data.rotate
          diff.rotate = 0
        Meteor.call 'messageUpdate', message._id, diff, done
      file.metadata =
        group: message.group
        root: message2root message
      Files.resumable.addFile file, e
  {buttonProps, dropProps, inputProps} = uploaderProps replaceFiles, replaceInput

  <>
    <input className="replaceInput" type="file" ref={replaceInput} {...inputProps}/>
    <TextTooltip title="Replace the file attachment of this message with a new file. Alternatively, you can drag a file onto this button. The old file will still be available through History.">
      <button className="btn btn-info replaceButton" tabIndex={tabindex} {...buttonProps} {...dropProps}>Replace File</button>
    </TextTooltip>
  </>
MessageReplace.displayName = 'MessageReplace'

export TableOfContentsID = React.memo ({messageID, parent, index}) ->
  message = useTracker ->
    Messages.findOne messageID
  , [messageID]
  return null unless message?
  <TableOfContents message={message} parent={parent} index={index}/>
TableOfContentsID.displayName = 'TableOfContentsID'

export TableOfContents = React.memo ({message, parent, index}) ->
  <ErrorBoundary>
    <WrappedTableOfContents message={message} parent={parent} index={index}/>
  </ErrorBoundary>
TableOfContents.displayName = 'TableOfContents'

tocItemTop = (item) ->
  itemTop = 0
  ancestor = item.parentNode
  while ancestor? and not /sticky/.test ancestor.className
    itemTop += ancestor.offsetTop
    ancestor = ancestor.offsetParent
  itemTop

tocHoverIndicator = _.debounce ->
  toc = document.querySelector 'nav.contents'
  return unless toc?  # not in a view with table of contents
  toc.previousSibling?.classList.remove 'active'
  toc.nextSibling?.classList.remove 'active'
  item = toc.querySelector '.hover'
  return unless item?  # no hovered item
  top = tocItemTop item
  if top < toc.scrollTop
    toc.previousSibling?.classList.add 'active'
  else if top > toc.scrollTop + toc.clientHeight
    toc.nextSibling?.classList.add 'active'
, 100

tocHoverItem = (e) ->
  id = e.target.dataset.id
  return unless id?
  document.querySelector "[data-message='#{id}'].message"
  ?.classList.toggle 'hover', e.type == 'mouseenter'

export WrappedTableOfContents = React.memo ({message, parent, index}) ->
  isRoot = not parent?  # should not differ between calls (for hook properties)
  formattedTitle = useTracker ->
    formatTitleOrFilename message,
      orUntitled: false
      bold: isRoot
  , [message, isRoot]
  user = useTracker ->
    Meteor.user()
  , []
  editing = editingMessage message, user
  folded = useTracker ->
    (messageFolded.get message._id) and
    not (routeHere message._id) and           # never fold if top-level message
    not editing                               # never fold if editing
  , [message._id, editing]
  #creator = useTracker ->
  #  displayUser message.creator
  #, [message.creator]
  author = useTracker ->
    if message.coauthors.length == 1
      displayUser message.coauthors[0]
    else if message.coauthors.length > 1
      (for author in message.coauthors
        displayUserLastName author
      ).join ', '
    else
      displayUser message.creator
  , [message.coauthors.join(' '), message.creator]
  children = useChildren message, true
  inView = useTracker ->
    messageInView.get message._id
  , [message._id]
  inner =
    <>
      {unless isRoot
        <div className="beforeMessageDrop"
         data-parent={parent} data-index={index}
         onDragEnter={addDragOver} onDragLeave={removeDragOver}
         onDragOver={dragOver} onDrop={dropOn}/>
      }
      <a href={pathFor 'message', {group: message.group, message: message._id}}
       data-id={message._id}
       className="onMessageDrop #{if isRoot then 'title' else ''} #{messageClass.call message} #{inView}"
       onDragStart={messageOnDragStart message}
       onDragEnter={addDragOver} onDragLeave={removeDragOver}
       onDragOver={dragOver} onDrop={dropOn}
       onMouseEnter={tocHoverItem} onMouseLeave={tocHoverItem}>
        <MessageIcons message={message}/>
        <span dangerouslySetInnerHTML={__html: formattedTitle}/>
        {' '}
        <span className="author">
          [{author}]
        </span>
      </a>
    </>
  renderedChildren = useMemo ->
    return unless children.length
    for [child, index] in children
      <TableOfContents key={child._id} message={child} parent={message._id} index={index}/>
  , [children]
  [hover, setHover] = useState false
  [tocFolded, setTocFolded] = useState Boolean message.minimized and not isRoot

  children =
    if renderedChildren?
      if tocFolded
        <div className="nav foldedContents" onClick={(e) -> setTocFolded false}>
          <div className="line"/>
        </div>
      else
        <ul className="nav subcontents #{if hover then 'hover' else ''}"
         onMouseOver={(e) -> setHover e.target == e.currentTarget}
         onMouseLeave={(e) -> setHover false if e.target == e.currentTarget}
         onClick={(e) -> setTocFolded true if e.target == e.currentTarget}>
          {renderedChildren}
        </ul>

  if isRoot
    <>
      <div className="top indicator"/>
      <nav className="contents" onScroll={tocHoverIndicator}>
        <ul className="nav contents">
          <li className="btn-group-xs #{if folded then 'folded' else ''}">
            {inner}
          </li>
        </ul>
        {children}
      </nav>
      <div className="bottom indicator"/>
    </>
  else
    <li className="btn-group-xs #{if folded then 'folded' else ''}">
      {inner}
      {children}
    </li>
WrappedTableOfContents.displayName = 'WrappedTableOfContents'

addDragOver = (e) ->
  e.preventDefault()
  e.stopPropagation()
  e.currentTarget.classList.add 'dragover'
  e.target.classList.add 'dragging'
removeDragOver = (e) ->
  return unless e.target == e.currentTarget
  e.preventDefault()
  e.stopPropagation()
  e.currentTarget.classList.remove 'dragover'
  e.target.classList.remove 'dragging'
dragOver = (e) ->
  return unless e.target == e.currentTarget
  e.preventDefault()
  e.stopPropagation()
dropOn = (e) ->
  e.preventDefault()
  e.stopPropagation()
  e.currentTarget.classList.remove 'dragover'
  dragId = e.dataTransfer?.getData 'application/coauthor-id'
  unless dragId
    url = e.dataTransfer?.getData 'text/plain'
    if url?
      url = parseCoauthorMessageUrl url
      if url?.hash
        dragId = url.hash[1..]
      else
        dragId = url?.message
  if (index = e.currentTarget.getAttribute 'data-index')
    index = parseInt index
    dropId = e.currentTarget.getAttribute 'data-parent'
  else
    dropId = e.currentTarget.getAttribute 'data-id'
  if dragId and dropId
    messageParent dragId, dropId, index

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
    if (match = ///(?:^\s*|[\[/:])(#{idRegex})\]?\s*$///.exec text)?
      msg = findMessage(match[1]) ? {_id: match[1]}  # allow unknown message ID
      if e.type == 'input' and t.parent.get()?._id != match[1] and
         msg.creator?  # hand-typed new good message ID
        t.$('.typeahead').typeahead 'close'
      t.parent.set msg
    else if (match = /^\s*Group:\s*(.*?)\s*$/i.exec text)?
      t.parent.set
        isGroup: true
        group: match[1]

  "click .messageParentButton": (e, t) ->
    e.preventDefault()
    e.stopPropagation()
    Modal.hide()
    parent = t.parent.get()
    return unless parent?
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

export SubmessageID = React.memo ({messageID, read}) ->
  message = useTracker ->
    Messages.findOne messageID
  , [messageID]
  return null unless message?
  <Submessage message={message} read={read}/>
SubmessageID.displayName = 'SubmessageID'

export Submessage = React.memo ({message, read}) ->
  <ErrorBoundary>
    <WrappedSubmessage message={message} read={read}/>
  </ErrorBoundary>
Submessage.displayName = 'Submessage'

messageInView = new ReactiveDict

## Maintain whether selection changed nontrivially recently, which causes
## the following click to be ignored by showTOC.
skipClick = false
document.addEventListener 'selectionchange', ->
  selection = document.getSelection()
  for i in [0...selection.rangeCount]
    range = selection.getRangeAt i
    unless range.startContainer == range.endContainer and
           range.startOffset == range.endOffset
      skipClick = true
      return
window.addEventListener 'click', -> skipClick = false

submessageCount = 0
export WrappedSubmessage = React.memo ({message, read}) ->
  here = useTracker ->
    routeHere message._id
  , [message._id]
  here = true if read
  tabindex0 = useMemo ->
    1 + 20 * submessageCount++
  , []
  user = useTracker ->
    Meteor.user()
  , []
  children = message.readChildren ? useChildren message
  can = useTracker ->
    delete: canDelete message._id
    undelete: canUndelete message._id
    publish: canPublish message._id
    unpublish: canUnpublish message._id
    minimize: canMinimize message._id
    unminimize: canUnminimize message._id
    pin: canPin message._id
    unpin: canUnpin message._id
    protect: canProtect message._id
    superdelete: canSuperdelete message._id
    private: canPrivate message._id
    parent: canMaybeParent message._id
    edit: canEdit message._id
    reply: canReply message
    super: canSuper message.group
    becomeSuper: canSuper message.group, false
  , [message._id]
  ref = useRef()
  [inViewRef, inView, intersection] = useInView
    threshold: [0, 1]
  fullIntersection = intersection?.intersectionRatio == 1
  setRef = useCallback (node) ->
    ref.current = node
    inViewRef node
  , [inViewRef]
  messageBodyRef = useRef()

  useLayoutEffect ->
    messageInView.set message._id,
      if inView
        if fullIntersection
          'active'
        else
          'active partial'
      else
        ''
    undefined
  , [inView, fullIntersection]

  if read  # should not change
    editing = raw = folded = false
    history = historyAll = null
    preview = messagePreviewDefault
  else
    ## Editing toggle
    [editTitle, setEditTitle] = useState ''
    [editBody, setEditBody] = useState null
      # special value null indicates meaning not editing so safe
    [editStopping, setEditStopping] = useState()
    safeToStopEditing = not editBody? or
      (message.title == editTitle and message.body == editBody)
    useEffect ->
      setMigrateSafe message._id, safeToStopEditing
      if editStopping and safeToStopEditing
        Meteor.call 'messageEditStop', message._id, (error, result) ->
          if error?
            console.error error
          else
            setEditStopping false
    , [editStopping, safeToStopEditing]
    ## When component unmounts, editor closes, so mark migration as safe.
    useEffect ->
      -> setMigrateSafe message._id, true
    , []

    ## Are we editing?
    editing = editingMessage message, user
    editing or= not safeToStopEditing  # Keep editing if unsaved changes
    raw = useTracker ->
      not editing and messageRaw.get message._id
    , [message._id, editing]
    folded = useTracker ->
      (messageFolded.get message._id) and
      not here and                         # never fold if top-level message
      not editing                          # never fold if editing
    , [message._id, here, editing]
    {history, historyAll} = useTracker ->
      history: messageHistory.get message._id
      historyAll: messageHistoryAll.get message._id
    , [message._id]
    history = null if editing
    preview = useTracker ->
      if history? or not editing  # Always show message in these views
        on: true
        sideBySide: false
      else
        messagePreviewGet message._id
    , [history?, editing, message._id]

    ## Title editing
    timer = useRef null
    lastTitle = useRef null
    savedTitles = useRef []
    useLayoutEffect ->
      if editing
        ## Initialize title and body when we start editing.
        unless lastTitle.current?
          setEditTitle lastTitle.current = message.title
          setEditBody message.body
        ## Update input's value when title changes on server
        else if message.title != lastTitle.current
          lastTitle.current = message.title
          ## Ignore an update that matches a title we sent to the server,
          ## to avoid weird reversion while live typing with network delays.
          ## (In steady state, we expect our saves to match later updates,
          ## so this should acquiesce with an empty savedTitles.)
          if message.title in savedTitles.current
            while savedTitles.current.pop() != message.title
              continue
          else
            ## Received new title: update input text, forget past saves,
            ## and cancel any pending save.
            setEditTitle message.title
            savedTitles.current = []
            Meteor.clearTimeout timer.current
      else
        lastTitle.current = null
        savedTitles.current = []
        setEditBody null
      undefined
    , [editing, editTitle, message.title]

    ## Maintain threadAuthors and threadMentions
    usernames = useTracker ->
      allUsernames()
    , []
    useLayoutEffect ->
      authors = message.coauthors
      for author in message.coauthors
        threadAuthors[author] ?= 0
        threadAuthors[author] += 1
      Session.set 'threadAuthors', threadAuthors
      mentions = atMentions message, usernames
      for author in mentions
        threadMentions[author] ?= 0
        threadMentions[author] += 1
      Session.set 'threadMentions', threadMentions
      ->
        threadAuthors[author] -= 1 for author in authors
        Session.set 'threadAuthors', threadAuthors
        threadMentions[author] -= 1 for author in mentions
        Session.set 'threadMentions', threadMentions
    , [message.coauthors.join(' '), message.title, message.body, usernames]

    ## One-time effects
    useEffect ->
      ## Maintain id2dom mapping
      id2dom[message._id] = ref.current
      checkImage message._id
      ## Scroll to this message if it's been requested.
      if scrollToLater == message._id
        scrollToLater = null
        scrollToMessage message._id
      ## Restore id2dom mapping
      ->
        delete id2dom[message._id]
        checkImage message._id
    , [message._id]

    ## Give focus to Title input if we just started editing this message,
    ## or if this is the only message (e.g., we just started a new thread).
    [startEdit, setStartEdit] = useState false
    useEffect ->
      if editing and (startEdit or (here and not message.children?.length))
        ref.current?.firstChild?.querySelector('input.title')?.focus()
        setStartEdit false if startEdit
      undefined
    , [editing, startEdit, here]

    ## Image reference counting:
    ## List images referenced by this message.
    ## If message is naturally folded, don't count images it references.
    [imageRefs, setImageRefs] = useState()
    [imageInternalRefs, setImageInternalRefs] = useState()
    natural = naturallyFolded message
    useEffect ->
      if natural or not messageBodyRef.current?
        setImageRefs undefined
        setImageInternalRefs undefined
      else
        messageImages = {}
        messageImagesInternal = {}
        for elt in messageBodyRef.current.querySelectorAll """
          img[src^="#{fileUrlPrefix}"],
          img[src^="#{fileAbsoluteUrlPrefix}"],
          img[src^="#{internalFileUrlPrefix}"],
          img[src^="#{internalFileAbsoluteUrlPrefix}"],
          video source[src^="#{fileUrlPrefix}"],
          video source[src^="#{fileAbsoluteUrlPrefix}"],
          video source[src^="#{internalFileUrlPrefix}"],
          video source[src^="#{internalFileAbsoluteUrlPrefix}"],
          div[data-messagepdf]
        """
          if elt.dataset.messagepdf
            messageImagesInternal[elt.dataset.messagepdf] = true
          else
            src = elt.getAttribute 'src'
            if 0 <= src.indexOf 'gridfs'
              messageImagesInternal[url2internalFile src] = true
            else
              messageImages[url2file src] = true
        setImageRefs (_.sortBy _.keys messageImages).join ','
        setImageInternalRefs (_.sortBy _.keys messageImagesInternal).join ','
    # too many dependencies to list
    ## Update image reference counts.
    useEffect ->
      return unless imageRefs?
      #console.log message._id, 'incrementing', imageRefs
      for id in imageRefs.split ','
        imageRefCount.set id, (imageRefCount.get(id) ? 0) + 1
        checkImage id
      for id in imageInternalRefs.split ','
        imageInternalRefCount.set id, (imageInternalRefCount.get(id) ? 0) + 1
      ->
        #console.log message._id, 'decrementing', imageRefs
        for id in imageRefs.split ','
          imageRefCount.set id, (imageRefCount.get(id) ? 0) - 1
          checkImage id
        for id in imageInternalRefs.split ','
          imageInternalRefCount.set id, (imageInternalRefCount.get(id) ? 0) - 1
    , [imageRefs, imageInternalRefs]
    ## Update default folded status of this message.
    useTracker ->
      ## Image gets unnaturally folded if it's referenced at least once
      ## and doesn't have any children (don't want to hide children, and this
      ## can also lead to infinite loop if children has the image reference)
      ## and doesn't refer to any other images (which can also lead to bad loops).
      newDefault = natural or
        (not message.children?.length and
        not imageRefs and not imageInternalRefs and
        (!!imageRefCount.get(message._id) or
          !!imageInternalRefCount.get(message.file)))
      if newDefault != defaultFolded.get message._id
        defaultFolded.set message._id, newDefault
        messageFolded.set message._id, newDefault
    , [message._id, message.file, natural, not message.children?.length, not imageRefs and not imageInternalRefs]

    absentTags = useTracker ->
      Tags.find
        group: message.group
        key: $nin: _.keys message.tags ? {}
        deleted: false
      ,
        sort: ['key']
      .fetch()
    , [message.group, _.keys(message.tags ? {}).join '\n']

  historified = history ? message
  messageFileType = useTracker ->
    if historified.file
      fileType historified.file
  , [historified.file]
  formattedTitle = useTracker ->
    for bold in [true, false]
      ## Only render unbold title if we have children (for back pointer)
      continue unless bold or message.children.length > 0
      if raw
        "<CODE CLASS='raw'>#{_.escape historified.title}</CODE>"
      else
        formatTitleOrFilename historified,
          orUntitled: false
          bold: bold
  , [historified.title, historified.file, historified.format, raw, message.children.length > 0]
  formattedBody = useTracker ->
    return historified.body unless historified.body
    if raw
      "<PRE CLASS='raw'>#{_.escape historified.body}</PRE>"
    else
      formatBody historified.format, historified.body, id: historified._id
  , [historified.body, historified.format, historified._id, raw]
  formattedFile = useTracker ->
    file = findFile historified.file
    return {} unless file?
    formatted = formatFile historified, file
    file:
      if raw and formatted
        "<PRE CLASS='raw'>#{_.escape formatted}</PRE>"
      else
        formatted
    description: formatFileDescription historified, file
  , [historified.file, historified._id, historified.diffId, raw]

  ## Support dragging rendered attachment like dragging message itself
  messageFileRef = useRef()
  useEffect ->
    return if folded or history? or not messageFileRef.current?
    listener = messageOnDragStart message
    elts = messageFileRef.current.querySelectorAll 'img, video, a, canvas'
    elt.addEventListener 'dragstart', listener for elt in elts
    -> elt.removeEventListener 'dragstart', listener for elt in elts
  , [folded, history?, message]

  ## Transform images
  ## Retransform when window width changes
  useElementWidth ref
  useEffect ->
    return unless messageBodyRef.current?
    ## Transform any images embedded within message body
    trackers =
      for img in messageBodyRef.current.querySelectorAll """
        img[src^="#{fileUrlPrefix}"],
        img[src^="#{fileAbsoluteUrlPrefix}"]
      """
        Tracker.autorun ->
          imgMessage = findMessage url2file img.src
          return unless imgMessage
          imageTransform img, messageRotate imgMessage
    ## Transform image file, respecting history
    if messageFileType == 'image' and
       img = messageFileRef.current.querySelector 'img'
      trackers.push Tracker.autorun ->
        imageTransform img, messageRotate historified
    -> tracker.stop() for tracker in trackers
  # too many dependencies to list

  ## Render embedded PDF files
  useEffect ->
    return unless messageBodyRef.current?
    elts =
      for elt in messageBodyRef.current.querySelectorAll 'div[data-messagepdf]'
        ReactDOM.render <MessagePDF file={elt.dataset.messagepdf}/>, elt
        elt
    ->
      ReactDOM.unmountComponentAtNode elt for elt in elts
  , [formattedBody]

  onFold = (e) ->
    e.preventDefault()
    e.stopPropagation()
    messageFolded.set message._id, not messageFolded.get message._id
    #$(e.currentTarget).tooltip 'hide'
  onRaw = (e) ->
    e.preventDefault()
    e.stopPropagation()
    messageRaw.set message._id, not messageRaw.get message._id
  onHistory = (e) ->
    e.preventDefault()
    e.stopPropagation()
    if messageHistory.get(message._id)?
      messageHistory.set message._id, null
    else
      messageHistory.set message._id, _.clone message
  onHistoryAll = (e) ->
    e.preventDefault()
    e.stopPropagation()
    messageHistoryAll.set message._id, not messageHistoryAll.get message._id
  onEdit = (e) ->
    e.preventDefault()
    e.stopPropagation()
    if editing
      if safeToStopEditing
        Meteor.call 'messageEditStop', message._id
      else
        setEditStopping true
    else
      setStartEdit true
      Meteor.call 'messageEditStart', message._id
  onChangeTitle = (e) ->
    newTitle = e.target.value
    setEditTitle newTitle
    Meteor.clearTimeout timer.current
    messageID = message._id
    timer.current = Meteor.setTimeout ->
      savedTitles.current.push newTitle
      Meteor.call 'messageUpdate', messageID,
        title: newTitle
    , idle
  onTagRemove = (e) ->
    e.preventDefault()
    tag = e.currentTarget.closest('.tagEdit')?.dataset.tag
    escaped = escapeTag tag
    if escaped of message.tags
      Meteor.call 'messageUpdate', message._id,
        tags: _.omit message.tags, escaped
      , (error) ->
        if error
          console.error error
        else
          Meteor.call 'tagDelete', message.group, tag, true
    else
      console.warn "Attempt to delete nonexistent tag '#{tag}' from message #{message._id}"
  onTagSelect = (e) ->
    e.preventDefault()
    tag = e.target.dataset.tag
    if tag of message.tags
      console.warn "Attempt to add duplicate tag '#{tag}' to message #{message._id}"
    else
      Meteor.call 'messageUpdate', message._id,
        tags: Object.assign {}, message.tags ? {}, {"#{escapeTag tag}": true}
  onTagEdit = (e, tag, tagVal, oldTag) ->
    e.preventDefault()
    if tag
      escaped = escapeTag tag
      exists = escaped of message.tags
      unless exists
        Meteor.call 'tagNew', message.group, tag
      tagVal or= true  # use special 'true' value instead of empty string
      if not oldTag? and tagVal == true and
         message.tags?[escaped] not in [undefined, true]
        console.warn "Not blanking tag '#{tag}' on message #{message._id} which already has value '#{message.tags[escaped]}'"
      else if tagVal != message.tags?[escaped]
        newTags = {...message.tags, "#{escapeTag tag}": tagVal}
        if (rename = oldTag? and oldTag.key != tag)
          delete newTags[escapeTag oldTag.key]
        Meteor.call 'messageUpdate', message._id,
          tags: newTags
        , (error) ->
          if error
            console.error error
          else if rename
            Meteor.call 'tagDelete', message.group, oldTag.key, true
      #else
      #  console.warn "No-op update tag '#{tag}' = '#{tagVal}' in message #{message._id}"
    false  ## prevent form from submitting
  ## Scroll the table of contents (if visible) to align with this message (if
  ## possible), and pulse the table of contents item (for when not possible).
  showTOC = (e) ->
    ## Find corresponding table of contents entry
    toc = document.querySelector 'nav.contents'
    return unless toc?  # not in a view with table of contents
    item = toc.querySelector "a[data-id='#{message._id}']"
    return unless item?  # this message is hidden in table of contents
    msgTop = e.currentTarget.getBoundingClientRect().top
    itemTop = tocItemTop item
    switch e.type
      when 'mouseenter'
        item.classList.add 'hover'
        tocHoverIndicator()
      when 'mouseleave'
        item.classList.remove 'hover'
        tocHoverIndicator()
      when 'click'
        return if skipClick  # ignore selecting clicks
        ## Ignore propagated click events e.g. from Action dropdown button
        ## or from Replace File hidden <input>.
        return unless /panel-heading|panel-title/.test e.target.className
        e.preventDefault()
        ## Scroll to align TOC item with message header
        toc.scroll
          top: itemTop - msgTop - 9  # fudge factor
          behavior: scrollBehavior()
        ## Pulse TOC item
        item.animate [
          transform: 'scale(1)'
        ,
          transform:
            if prefersReducedMotion() then 'scale(1)' else 'scale(0.95)'
          backgroundColor: '#888'
        ,
          transform: 'scale(1)'
        ],
          duration: 500
          iterations: 3

  <div className="panel message #{messagePanelClass message, editing}" data-message={message._id} id={message._id} ref={setRef}>
    <div className="panel-heading clearfix" onClick={showTOC}
     onMouseEnter={showTOC} onMouseLeave={showTOC}>
      {if editing and not history?
        <input className="push-down form-control title" type="text" placeholder="Title" value={editTitle} onChange={onChangeTitle} tabIndex={tabindex0+18}/>
      else
        <span className="message-title">
          <span className="message-left-buttons push-down btn-group btn-group-xs">
            {unless here
              <>
                {unless read
                  if folded
                    <TextTooltip title="Open/unfold this message so that you can see its contents. Does not affect other users.">
                      <button className="btn btn-info foldButton hidden-print" aria-label="Unfold" onClick={onFold}>
                        <span className="fas fa-plus" aria-hidden="true"/>
                      </button>
                    </TextTooltip>
                  else
                    <TextTooltip title="Close/fold this message, e.g. to skip over its contents. Does not affect other users.">
                      <button className="btn btn-info foldButton hidden-print" aria-label="Fold" onClick={onFold}>
                        <span className="fas fa-minus" aria-hidden="true"/>
                      </button>
                    </TextTooltip>
                }
                <TextTooltip title="Zoom in/focus on just the subthread of this message and its descendants">
                  <a className="btn btn-info focusButton" aria-label="Focus" href={pathFor 'message', {group: message.group, message: message._id}} draggable="true" onDragStart={messageOnDragStart message}>
                    <span className="fas fa-sign-in-alt" aria-hidden="true"/>
                  </a>
                </TextTooltip>
              </>
            else
              <MessageNeighborsOrParent message={message}/>
            }
          </span>
          <span className="space"/>
          <MessageIcons message={historified}/>
          <span className="title panel-title"
           dangerouslySetInnerHTML={__html: formattedTitle[0]}/>
          <MessageTags message={historified}/>
          <MessageLabels message={historified}/>
        </span>
      }
      {if editing
        <span className="message-subtitle">
          <span className="upper-strut"/>
          <span className="tags">
            {for tag in sortTags message.tags
              <React.Fragment key={tag.key}>
                <TagEdit tag={tag} className="label label-default outer-label"
                 onTagEdit={onTagEdit} onTagSelect={onTagSelect}
                 onTagRemove={onTagRemove}>
                  <TagList tag={tag} noLink/>
                  {### Old direct removal button
                  <span className="tagRemove fas fa-times-circle" aria-label="Remove" data-tag={tag.key} onClick={onTagRemove}/>
                  ###}
                </TagEdit>
                {' '}
              </React.Fragment>
            }
          </span>
          <TagEdit tags={absentTags}
           className="label label-default outer-label"
           onTagEdit={onTagEdit} onTagSelect={onTagSelect}>
            <span className="label label-default">
              <span className="fas fa-plus" aria-label="Add"/>
              {' Tag'}
            </span>
          </TagEdit>
          <MessageLabels message={message}/>
          <span className="lower-strut"/>
        </span>
      }
      {### Buttons and badge on the right of the message ###}
      <div className="pull-right hidden-print message-right-buttons">
        {unless message.root
          <TextTooltip title="Number of submessages within thread">
            <span className="badge">{message.submessageCount}</span>
          </TextTooltip>
          <span className="space"/>
        }
        <div className="btn-group">
          {unless folded or editing or read
            <>
              {if raw
                <TextTooltip title="Switch back to viewing the formatted message.">
                  <button className="btn btn-default rawButton" tabIndex={tabindex0+1} onClick={onRaw}>Formatted</button>
                </TextTooltip>
              else
                <TextTooltip title="Switch to viewing raw source code. Useful for copy/pasting into another message, or to see how something was done.">
                  <button className="btn btn-default rawButton" tabIndex={tabindex0+1} onClick={onRaw}>Raw</button>
                </TextTooltip>
              }
              {unless history
                <TextTooltip title="View past versions of this message, and who edited when">
                  <button className="btn btn-default historyButton" tabIndex={tabindex0+2} onClick={onHistory}>History</button>
                </TextTooltip>
              }
            </>
          }
          {if history?
            <>
              {if historyAll
                <TextTooltip title="Switch back to showing just the versions when this message stopped being edited.">
                  <button className="btn btn-default historyAllButton" tabIndex={tabindex0+2} onClick={onHistoryAll}>Show Finished</button>
                </TextTooltip>
              else
                <TextTooltip title="Show every version of this message (recorded roughly every two seconds), instead of just the versions when the message stopped being edited. Useful if the version you need is missing.">
                  <button className="btn btn-default historyAllButton" tabIndex={tabindex0+2} onClick={onHistoryAll}>Show All</button>
                </TextTooltip>
              }
              <TextTooltip title="Return to viewing the present version of this message">
                <button className="btn btn-default historyButton" tabIndex={tabindex0+3} onClick={onHistory}>Exit History</button>
              </TextTooltip>
            </>
          }
          {if editing
            <>
              {if can.super and not message.root?
                <ThreadPrivacy message={message} tabindex={tabindex0+5}/>
              }
              <KeyboardSelector messageID={message._id} tabindex={tabindex0+6}/>
              <FormatSelector messageID={message._id} format={message.format} tabindex={tabindex0+7}/>
            </>
          }
          {unless history or read
            <>
              <MessageActions message={message} can={can} editing={editing} tabindex0={tabindex0}/>
              {if editing
                <OverlayTrigger flip overlay={(props) ->
                  <Tooltip {...props}>
                    {if editStopping
                      <>Waiting for message to save before stopping editing...</>
                    else
                      <>
                        <p>Close editor and mark this version as &quot;finished&quot;. (Your edits are already saved, and users with access to this message can already see your edits.)</p>
                        {unless message.published
                          <p>Don't forget to <b>publish</b> your message when you're ready for others to see it!</p>
                        }
                        {if message.deleted
                          <p><b>Undelete</b> your message if you want others to see it.</p>
                        }
                      </>
                    }
                  </Tooltip>
                }>
                  <span className="wrapper #{if editStopping then 'disabled' else ''}">
                    <button className="btn btn-info editButton" onClick={onEdit}
                     disabled={editStopping} tabIndex={tabindex0+8}>
                      Stop Editing
                    </button>
                  </span>
                </OverlayTrigger>
              else unless folded
                <>
                  {if message.file and can.edit
                    <MessageReplace message={message} tabindex={tabindex0+7}/>
                  }
                  <OverlayTrigger flip overlay={(props) ->
                    <Tooltip {...props}>
                      {if can.edit
                        <p>
                          Start editing this message (possibly with other users).
                          {unless amCoauthor message, user
                            <><br/>Changes will automatically make you a coauthor.</>
                          }
                        </p>
                      else unless messageRoleCheck message.group, message, 'edit', user
                        <p>
                          You do not have edit permissions in this group/thread.
                        </p>
                      }
                      {if message.protected
                        <p>Message is <b>protected</b>, so edits are restricted to coauthors and superusers.</p>
                      }
                      {if can.becomeSuper and not can.edit
                        <p>Become Superuser (or type <kbd>s</kbd>) to edit this message.</p>
                      }
                    </Tooltip>
                  }>
                    <span className="wrapper #{if can.edit then '' else 'disabled'}">
                      <button className="btn btn-info editButton"
                       tabIndex={tabindex0+8} onClick={onEdit}
                       disabled={not can.edit}>
                        Edit
                        {if message.protected
                          <>
                            {' '}
                            <span className="fas fa-lock"/>
                          </>
                        }
                      </button>
                    </span>
                  </OverlayTrigger>
                </>
              }
            </>
          }
        </div>
      </div>
    </div>
    {unless folded
      previewSideBySide = preview.on and preview.sideBySide
      <>
        {if history?
          <MessageHistory message={message}/>
        }
        <div className="editorAndBody clearfix #{if previewSideBySide then 'sideBySide' else ''}">
          <div className="editorContainer">
            {if editing
              <>
                <MessageEditor message={message} setEditBody={setEditBody} tabindex={tabindex0+19}/>
                {unless previewSideBySide
                  <BelowEditor message={message} preview={preview} safeToStopEditing={safeToStopEditing} editStopping={editStopping}/>
                }
              </>
            }
          </div>
          {if preview.on
            <div className="bodyContainer" style={{height: if previewSideBySide then preview.height else 'auto'}}>
              {if historified.file and editing
                <div className="fileDescription">
                  <div className="fileDescriptionText">
                    <span className="fas fa-paperclip"/>
                    {' '}
                    <span dangerouslySetInnerHTML={__html: formattedFile.description}/>
                  </div>
                  <div className="file-right-buttons btn-group hidden-print">
                    {if messageFileType == 'image'
                      <MessageImage message={message}/>
                    }
                    <MessageReplace message={message} tabindex={tabindex0+9}/>
                  </div>
                </div>
              }
              <div className="panel-body">
                <div className="message-body" ref={messageBodyRef}
                 dangerouslySetInnerHTML={__html: formattedBody}/>
                {if messageFileType == 'pdf'
                  <MessagePDF file={message.file}/>
                }
                {if historified.file
                  <>
                    <p className="message-file" ref={messageFileRef}
                     dangerouslySetInnerHTML={__html: formattedFile.file}/>
                    <p className="message-file-description"
                     dangerouslySetInnerHTML={__html: formattedFile.description}/>
                  </>
                }
              </div>
            </div>
          }
        </div>
        {if previewSideBySide
          <BelowEditor message={message} preview={preview} safeToStopEditing={safeToStopEditing} editStopping={editStopping}/>
        }
        <div className="message-footer">
          <MessageAuthor message={historified} also={history?}/>
          <div className="message-response-buttons clearfix hidden-print">
            {unless read
              <EmojiButtons message={message} can={can}/>
            }
            {if editing
              <div className="btn-group pull-right">
                {if editStopping
                  <button className="btn btn-info editButton disabled" title="Waiting for save to complete before stopping editing...">
                    Stop Editing
                  </button>
                else
                  <button className="btn btn-info editButton" onClick={onEdit}>
                    Stop Editing
                  </button>
                }
                {if can.reply
                  <ReplyButtons message={message} prefix="Another "/>
                }
              </div>
            else
              if can.reply and not read
                <ReplyButtons message={message}/>
            }
          </div>
        </div>
        {if children.length
          <>
            <div className="children clearfix">
              {for child in children
                <Submessage key={child._id} message={child} read={read}/>
              }
            </div>
            <div className="panel-body panel-secondbody hidden-print clearfix">
              {if can.reply and not read
                <ReplyButtons message={message}/>
              }
              <span className="message-title">
                <a className="btn btn-default btn-xs linkToTop" aria-label="Top" href="##{message._id}">
                  <span className="fas fa-caret-up"/>
                </a>
                <span className="space"/>
                <MessageIcons message={historified}/>
                <span className="panel-title"
                dangerouslySetInnerHTML={__html: formattedTitle[1]}/>
                <MessageTags message={message}/>
                <MessageLabels message={message}/>
              </span>
            </div>
          </>
        }
      </>
    }
  </div>
WrappedSubmessage.displayName = 'WrappedSubmessage'

export MessageActions = React.memo ({message, can, editing, tabindex0}) ->
  myUsername = useTracker ->
    Meteor.user()?.username
  , []

  onPublish = (e) ->
    e.preventDefault()
    ## Stop editing if we are publishing.
    #if not message.published and editing
    #  Meteor.call 'messageEditStop', message._id
    Meteor.call 'messageUpdate', message._id,
      published: not message.published
      finished: true
  onDelete = (e) ->
    e.preventDefault()
    ## Stop editing if we are deleting.
    if not message.deleted and editing
      Meteor.call 'messageEditStop', message._id
    Meteor.call 'messageUpdate', message._id,
      deleted: not message.deleted
      finished: true
  onSuperdelete = (e) ->
    e.preventDefault()
    Modal.show 'superdelete', message
  onPrivate = (e) ->
    e.preventDefault()
    Meteor.call 'messageUpdate', message._id,
      private: not message.private
      finished: true
  onMinimize = (e) ->
    e.preventDefault()
    Meteor.call 'messageUpdate', message._id,
      minimized: not message.minimized
      finished: true
  onPin = (e) ->
    e.preventDefault()
    Meteor.call 'messageUpdate', message._id,
      pinned: not message.pinned
      finished: true
  onProtect = (e) ->
    e.preventDefault()
    Meteor.call 'messageUpdate', message._id,
      protected: not message.protected
      finished: true
  onParent = (e) ->
    e.preventDefault()
    oldParent = findMessageParent message
    oldIndex = oldParent?.children.indexOf message._id
    Modal.show 'messageParentDialog',
      child: message
      oldParent: oldParent
      oldIndex: oldIndex
  onCoauthor = (e) ->
    e.preventDefault()
    ###
    if myUsername in message.coauthors
      Meteor.call 'messageUpdate', message._id,
        coauthors: $pull: [myUsername]
        finished: true
    else
    ###
    Meteor.call 'messageUpdate', message._id,
      coauthors: $addToSet: [myUsername]
      finished: true

  return null unless can.pin or can.unpin or can.minimize or can.unminimize or can.delete or can.undelete or can.publish or can.unpublish or can.superdelete or can.private or can.protect
  <Dropdown className="btn-group">
    <Dropdown.Toggle variant="info" tabIndex={tabindex0+4}>
      {"Action "}
      <span className="caret"/>
    </Dropdown.Toggle>
    <Dropdown.Menu align="right" className="actionMenu buttonMenu">
      {if message.pinned
        if can.unpin
          <li>
            <Dropdown.Item className="pinMsgButton" href="#">
              <TextTooltip placement="left" title="Remove this message's pin, marking it as no longer important for everyone.">
                <button className="btn btn-danger btn-block" onClick={onPin}>Unpin</button>
              </TextTooltip>
            </Dropdown.Item>
          </li>
      else
        if can.pin
          <li>
            <Dropdown.Item className="pinMsgButton" href="#">
              <TextTooltip placement="left" title="Pin this message, marking it as important for everyone. Pinned messages are listed at the bottom of the thread.">
                <button className="btn btn-success btn-block" onClick={onPin}>Pin</button>
              </TextTooltip>
            </Dropdown.Item>
          </li>
      }
      {if message.minimized
        if can.unminimize
          <li>
            <Dropdown.Item className="minimizeButton" href="#">
              <OverlayTrigger placement="left" flip overlay={(props) -> <Tooltip {...props}>Open/unfold this message <b>for all users</b>. Use this if a discussion becomes relevant again. If you just want to open/unfold the message to see it yourself temporarily, use the [+] button on the left.</Tooltip>}>
                <button className="btn btn-success btn-block" onClick={onMinimize}>Unminimize</button>
              </OverlayTrigger>
            </Dropdown.Item>
          </li>
      else
        if can.minimize
          <li>
            <Dropdown.Item className="minimizeButton" href="#">
              <OverlayTrigger placement="left" flip overlay={(props) -> <Tooltip {...props}>Close/fold this message <b>for all users</b>. Use this to clean up a thread when the discussion of this message (and all its replies) is resolved/no longer important. If you just want to close/fold the message yourself temporarily, use the [−] button on the left.</Tooltip>}>
                <button className="btn btn-danger btn-block" onClick={onMinimize}>Minimize</button>
              </OverlayTrigger>
            </Dropdown.Item>
          </li>
      }
      {if message.deleted and can.undelete
        <li>
          <TextTooltip placement="left" title="Undelete this message, restoring its visibility to everyone. Use Delete when you've made a practical mistake (e.g. didn't mean to click Reply). But if you had a content misunderstanding or question that since got resolved, consider using Minimize to preserve that discussion for others to look at if desired.">
            <Dropdown.Item className="deleteButton" href="#">
              <button className="btn btn-success btn-block" onClick={onDelete}>Undelete</button>
            </Dropdown.Item>
          </TextTooltip>
        </li>
      }
      {if message.deleted and can.superdelete
        <li>
          <TextTooltip placement="left" title="Permanently deletes this message and all of its history, as if it never happened. Dangerous and non-undoable operation, so has a confirmation dialog.">
            <Dropdown.Item className="superdeleteButton" href="#">
              <button className="btn btn-danger btn-block" onClick={onSuperdelete}>Superdelete</button>
            </Dropdown.Item>
          </TextTooltip>
        </li>
      }
      {if not message.published and can.publish
        <li>
          <TextTooltip placement="left" title="Use Publish when your message is ready to be shared with the group. Even if it's a partly formed idea, it may inspire more!">
            <Dropdown.Item className="publishButton" href="#">
              <button className="btn btn-success btn-block" onClick={onPublish}>Publish</button>
            </Dropdown.Item>
          </TextTooltip>
        </li>
      }
      {if not message.deleted and can.delete
        <li>
          <TextTooltip placement="left" title="Delete this message, making it invisible to everyone except coauthors and superusers. Use Delete when you've made a practical mistake (e.g. didn't mean to click Reply). But if you had a content misunderstanding or question that since got resolved, consider using Minimize to preserve that discussion for others to look at if desired.">
            <Dropdown.Item className="deleteButton" href="#">
              <button className="btn btn-danger btn-block" onClick={onDelete}>Delete</button>
            </Dropdown.Item>
          </TextTooltip>
        </li>
      }
      {if message.published and can.unpublish
        <li>
          <TextTooltip placement="left" title="Unpublish this message, making it invisible to everyone except coauthors and superusers. Use Unpublish (ideally when starting a message) if you still want to work on this message, but it isn't yet ready to share with the group.">
            <Dropdown.Item className="publishButton" href="#">
              <button className="btn btn-danger btn-block" onClick={onPublish}>Unpublish</button>
            </Dropdown.Item>
          </TextTooltip>
        </li>
      }
      {if can.private
        <li>
          <TextTooltip placement="left" title="Change the privacy of this message. Private messages can be seen only by coauthors you list, those you add to the access list, and superusers.">
            <Dropdown.Item className="privateButton" href="#">
              {if message.private
                <button className="btn btn-success btn-block" onClick={onPrivate}>Make Public</button>
              else
                <button className="btn btn-danger btn-block" onClick={onPrivate}>Make Private</button>
              }
            </Dropdown.Item>
          </TextTooltip>
        </li>
      }
      {if can.protect
        <li>
          <TextTooltip placement="left" title="Toggle whether this message is protected, meaning that it can be edited only by coauthors and superusers (but can still be seen normally and get emoji responses).">
            <Dropdown.Item className="protectButton" href="#">
              {if message.protected
                <button className="btn btn-success btn-block" onClick={onProtect}>Unprotect</button>
              else
                <button className="btn btn-danger btn-block" onClick={onProtect}>Protect</button>
              }
            </Dropdown.Item>
          </TextTooltip>
        </li>
      }
      {if can.parent
        <li>
          <Dropdown.Item className="parentButton" href="#">
            <TextTooltip placement="left" title='Re-organize messages by making this message a reply (child) of a different message (parent), or split it off into a new thread (by choosing the group itself as the new "parent").'>
              <button className="btn btn-warning btn-block" onClick={onParent}>Move</button>
            </TextTooltip>
          </Dropdown.Item>
        </li>
      }
      {if can.edit and myUsername not in message.coauthors
        <li>
          <Dropdown.Item className="coauthorButton" href="#">
            <TextTooltip placement="left" title="Add yourself as a coauthor to this message, indicating that you contributed to its content or ideas. Edit the message for more details and control.">
              <button className="btn btn-info btn-block" onClick={onCoauthor}>Coauthor</button>
            </TextTooltip>
          </Dropdown.Item>
        </li>
      }
      {###
      if can.edit and myUsername in message.coauthors and (message.coauthors.length > 1 or message.coauthors[0] != myUsername)
        <li>
          <Dropdown.Item className="coauthorButton" href="#">
            <button className="btn btn-danger btn-block" onClick={onCoauthor}>Uncoauthor</button>
          </Dropdown.Item>
        </li>
      ###}
    </Dropdown.Menu>
  </Dropdown>
MessageActions.displayName = 'MessageActions'

messageAuthorSubtitle = (message, author) -> ->
  if (updated = message.authors[escapeUser author])?
    (if message.creator == author
      "Created this message and last edited "
    else
      "Last edited this message "
    ) + formatDate updated, 'on '
  else
    "No explicit edit to this message"

export MessageAuthor = React.memo ({message, also}) ->
  if also
    also = {}
    also[unescapeUser author] = updated for author, updated of message.authors
  count = 0
  <div className="author text-right">
    {'(by '}
    {for author in message.coauthors
      delete also[author] if also
      <React.Fragment key={author}>
        {', ' if count++}
        <UserLink group={message.group} username={author}
         subtitle={messageAuthorSubtitle message, author}/>
      </React.Fragment>
    }
    {if also and not _.isEmpty also
      for author, updated of also
        <React.Fragment key={author}>
          {', ' if count++}
          (<UserLink group={message.group} username={author}
           subtitle={-> "Edited this message #{formatDate updated, 'on '} but no longer a coauthor"}/>)
        </React.Fragment>
    }
    {if message.access?.length and message.published and not message.deleted
      count = 0
      <>
        {'; access to '}
        {for user in message.access
          <React.Fragment key={user}>
            {', ' if count++}
            <UserLink group={message.group} username={user}
             subtitle="On explicit access list"/>
          </React.Fragment>
        }
      </>
    }
    {if message.published
      '; posted '
    else
      '; created '
    }
    <FormatDate date={message.published or message.created}/>
    {unless (message.published or message.created) == message.updated
      <>
        {'; last updated '}
        <FormatDate date={message.updated}/>
      </>
    }
    {')'}
  </div>
MessageAuthor.displayName = 'MessageAuthor'
