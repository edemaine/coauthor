import React, {useEffect, useMemo, useRef, useState} from 'react'
import Dropdown from 'react-bootstrap/Dropdown'
import OverlayTrigger from 'react-bootstrap/OverlayTrigger'
import Tooltip from 'react-bootstrap/Tooltip'
import {useTracker} from 'meteor/react-meteor-data'
import Blaze from 'meteor/gadicc:blaze-react-component'

import {ErrorBoundary} from './ErrorBoundary'
import {FormatDate} from './lib/date'
import {MessageLabels, MessageTags, messageClass, uploaderProps} from './message.coffee'
import {TagEdit} from './TagEdit'
import {TagList} from './TagList'
import {TextTooltip} from './lib/tooltip'
import {UserLink} from './UserLink'
import {emojiReplies} from '/lib/emoji'
import {formatTitleOrFilename} from '/lib/formats'
import {groupDefaultSort, sortKeys} from '/lib/groups'
import {autopublish} from '/lib/settings'
import {groupTags} from '/lib/tags'

@routeGroup = ->
  Router.current()?.params?.group

@routeGroupOrWild = ->
  routeGroup() ? wildGroup

Template.registerHelper 'routeGroup', routeGroup

Template.registerHelper 'routeGroupOrWildData', ->
  group: routeGroupOrWild()
  0: '*'

Template.registerHelper 'wildGroup', ->
  routeGroup() == wildGroup

@groupData = (group) ->
  Groups.findOne
    name: group ? routeGroup()

Template.registerHelper 'groupData', groupData

Template.registerHelper 'groupDataOrWild', ->
  routeGroup() == wildGroup or groupData()

@routeSortBy = ->
  if Router.current().params.sortBy in sortKeys
    key: Router.current().params.sortBy
    reverse: Router.current().route.getName()[-7..] == 'reverse'
  else
    groupDefaultSort routeGroup()

@linkToSort = (sort) ->
  if sort.reverse
    route = 'group.sorted.reverse'
  else
    route = 'group.sorted.forward'
  pathFor route,
    group: routeGroup()
    sortBy: sort.key

Template.registerHelper 'groups', ->
  Groups.find {},
    sort: [['name', 'asc']]

Template.registerHelper 'admin', -> canAdmin routeGroup(), routeMessage()

Template.registerHelper 'canSuper', -> canSuper @group ? routeGroup()

Template.group.helpers
  MaybeGroup: -> MaybeGroup

export MaybeGroup = React.memo ({group}) ->
  useEffect ->
    setTitle()
    undefined
  , []
  groupData = useTracker ->
    Groups.findOne
      name: group
  , [group]

  if groupData?
    <ErrorBoundary>
      <Group group={group} groupData={groupData}/>
    </ErrorBoundary>
  else
    <Blaze template="badGroup" group={group}/>
MaybeGroup.displayName = 'MaybeGroup'

export Group = React.memo ({group, groupData}) ->
  sortBy = useTracker ->
    routeSortBy()
  , []
  topMessages = useTracker ->
    groupSortedBy group, sortBy
  , [group, sortBy]
  can = useTracker ->
    post: canPost group
    import: canImport group
    globalSuper: canSuper wildGroup
  , [group]

  <div className="panel panel-primary">
    <div className="panel-heading clearfix">
      <span className="push-down btn-group btn-group-xs">
        <div className="fake-btn">&#8203;</div>
      </span>
      <span className="title panel-title">
        {group}
      </span>
      <ErrorBoundary>
        <GroupButtons group={group} can={can} sortBy={sortBy}/>
      </ErrorBoundary>
    </div>
    <ErrorBoundary>
      <MessageList group={group} topMessages={topMessages} sortBy={sortBy}/>
    </ErrorBoundary>
    <div className="panel-footer clearfix">
      <ErrorBoundary>
        <ImportExportButtons group={group} can={can}/>
      </ErrorBoundary>
      <i>{pluralize topMessages.length, 'message thread'}</i>
      <ErrorBoundary>
        <GroupTags group={group}/>
      </ErrorBoundary>
      <p className="clearfix"/>
      <ErrorBoundary>
        <GroupMembers group={group}/>
      </ErrorBoundary>
    </div>
  </div>
Group.displayName = 'Group'

export GroupButtons = React.memo ({group, can, sortBy}) ->
  superuser = useTracker ->
    Session.get 'super'
  , []
  user = useTracker ->
    Meteor.user()
  , []
  postTitle = useMemo ->
    if can.post
      'Start a new thread / problem / discussion with a new top-level message.'
    else if user?
      'You do not have permission to post a message in this group.'
    else
      'You need to be logged in to post a message in this group.'
  , [can.post, user?]
  defaultPublished = useTracker ->
    autopublish()
  , []
  [dropdown, setDropdown] = useState false

  onSortSetDefault = (e) ->
    e.stopPropagation()
    console.log "Setting default sort for #{group} to #{if sortBy.reverse then '-' else '+'}#{sortBy.key}"
    Meteor.call 'groupDefaultSort', group, sortBy
  onRename = (e) ->
    Modal.show 'groupRename'
  onPost = (e) ->
    e.preventDefault()
    e.stopPropagation()
    newTab = (e.button != 0) or e.ctrlKey or e.metaKey or e.shiftKey
    #e.target.addClass 'disabled'
    setDropdown false  # not automatic for auxclick
    return unless canPost group
    message = {}
    switch e.currentTarget.getAttribute 'data-published'
      when 'false'
        message.published = false
      when 'true'
        message.published = true
      else
        message.published = defaultPublished
    Meteor.call 'messageNew', group, null, null, message, (error, result) ->
      #e.target.removeClass 'disabled'
      if error
        console.error error
      else if result
        Meteor.call 'messageEditStart', result
        if newTab
          url = urlFor 'message',
            group: group
            message: result
          window.open url, '_blank'
        else
          Router.go 'message',
            group: group
            message: result
      else
        console.error "messageNew did not return problem -- not authorized?"

  <div className="pull-right group-right-buttons">
    {if superuser
      <div className="btn-group">
        <button className="btn btn-warning sortSetDefault" onClick={onSortSetDefault}>
          Set Group Default Sort
        </button>
        {if can.globalSuper
          <button className="btn btn-danger groupRenameButton" onClick={onRename}>
            Rename Group
          </button>
        }
      </div>
    }
    
    <Dropdown className="btn-group" show={dropdown}
     onToggle={(open) -> setDropdown open}>
      <TextTooltip title={postTitle}>
        <span className="wrapper #{if can.post then '' else 'disabled'}">
          <Dropdown.Toggle variant="info" disabled={not can.post}>
            {'New Thread '}
            <span className="caret"/>
          </Dropdown.Toggle>
        </span>
      </TextTooltip>
      <Dropdown.Menu className="buttonMenu postMenu">
        <li>
          <Dropdown.Item href="#" onClick={onPost} onAuxClick={onPost}>
            <TextTooltip placement="left" title="Start a new root message, #{if defaultPublished then 'immediately ' else ''}visible to everyone in this group#{if defaultPublished then '' else ' (once published)'}.">
              <button className="btn btn-#{if defaultPublished then 'default' else 'warning'} btn-block postButton">
                New Root Message
              </button>
            </TextTooltip>
          </Dropdown.Item>
        </li>
        <li>
          <Dropdown.Item href="#" data-published={not defaultPublished}
           onClick={onPost} onAuxClick={onPost}>
            {if defaultPublished
              <TextTooltip placement="left" title="Start a new root message that starts in the unpublished state, so it will become generally visible only when you select Action / Publish.">
                <button className="btn btn-warning btn-block postButton">
                  New Unpublished Root Message
                </button>
              </TextTooltip>
            else
              <TextTooltip placement="left" title="Start a new root message that starts in the published state, so everyone in this group can see it immediately.">
                <button className="btn btn-success btn-block postButton">
                  New Published Root Message
                </button>
              </TextTooltip>
            }
          </Dropdown.Item>
        </li>
      </Dropdown.Menu>
    </Dropdown>
    <div className="btn-group">
      <TextTooltip title="Show all messages you have authored or been @mentioned in">
        <a className="btn btn-default myPostsButton #{unless user? then 'disabled'}"
         href={if user? then pathFor 'author', {group: group, author: user.username}}>
          My Posts
        </a>
      </TextTooltip>
      <TextTooltip title="Show the last n messages, updating live">
        <a className="btn btn-default liveButton"
         href={pathFor 'live', group: group}>
          Live Feed
        </a>
      </TextTooltip>
      <TextTooltip title="Show all messages since a specified time in the past">
        <a className="btn btn-default sinceButton"
         href={pathFor 'since', group: group}>
          Catchup Since...
        </a>
      </TextTooltip>
      <TextTooltip title="Plot number of messages over time, by you and for entire group">
        <a className="btn btn-default statsButton"
         href={pathFor 'stats', {group: group, username: user?.username}}>
          Statistics
        </a>
      </TextTooltip>
    </div>
  </div>
GroupButtons.displayName = 'GroupButtons'

columnCenter =
  posts: true
  emoji: true
  subscribe: true

## Default reverse setting when switching sort keys:
columnReverse =
  published: true
  updated: true
  posts: true
  emoji: true
  subscribe: true

export MessageList = React.memo ({group, topMessages, sortBy}) ->
  tags = useTracker ->
    Tags.find
      group: group
      deleted: false
    ,
      sort: ['key']
    .fetch()
  , [group]
  sortLink = (key) ->
    if key == sortBy.key
      linkToSort
        key: key
        reverse: not sortBy.reverse
    else
      linkToSort
        key: key
        reverse: key of columnReverse

  <table className="table table-striped">
    <thead>
      <tr>
        {for column, title of (
          title: 'Title of first (root) message in thread'
          creator: 'User who initially started the thread'
          published: 'When original thread was published/created'
          updated: 'Last update of any submessage in thread'
          posts: 'Number of public submessages in thread (excluding root message)'
          emoji: 'Number of positive emoji reactions to root message of thread'
          #emojiNeg:
          subscribe: 'Whether you subscribe to notifications about this thread (see Settings for default)'
        )
          <th key={column}
           className={if column of columnCenter then 'text-center'}>
            <TextTooltip title={title}>
              <a href={sortLink column}>
                {switch column
                  when 'subscribe'
                    'Sub'
                  when 'emoji'
                    <span className="fas fa-thumbs-up positive"/>
                  else
                    capitalize column
                }
                {if sortBy.key == column
                  if sortBy.key in ['title', 'creator']
                    type = 'alpha'
                  else
                    type = 'numeric'
                  if sortBy.reverse
                    order = 'up'
                  else
                    order = 'down'
                  <span className="fas fa-sort-#{type}-#{order}"/>
                }
              </a>
            </TextTooltip>
            {if column == 'title'
              <span className="gatherBtn">
                <TagEdit tags={tags} className="label label-default">
                  Gather by...
                </TagEdit>
              </span>
            }
          </th>
        }
      </tr>
    </thead>
    <tbody>
      {for message in topMessages
        #if canSee message
        #<a className="list-group-item" href={messageLink}>
        <ErrorBoundary key={message._id}>
          <MessageShort message={message}/>
        </ErrorBoundary>
      }
    </tbody>
  </table>
MessageList.displayName = 'MessageList'

export ImportExportButtons = React.memo ({group, can}) ->
  onImport = (files, e) ->
    import('/imports/import.coffee').then (i) ->
      i.importFiles e.target.getAttribute('data-format'), group, files
  osqaRef = useRef()
  latexRef = useRef()
  osqaProps = uploaderProps onImport, osqaRef
  latexProps = uploaderProps onImport, latexRef
  onSuperdeleteImported = (e) ->
    Modal.show 'superdeleteImport', {group}
  onDownload = (e) ->
    Modal.show 'downloadGroup', {group}

  <div className="btn-group pull-right">
    {if can.import
      <>
        <input className="importInput" type="file" data-format="osqa"
         accept=".zip" ref={osqaRef} {...osqaProps.inputProps}/>
        <button className="btn btn-default importButton" data-format="osqa"
         {...osqaProps.buttonProps}>
          Import OSQA
        </button>
        <input className="importInput" type="file" data-format="latex"
         accept=".zip" ref={latexRef} {...latexProps.inputProps}/>
        <button className="btn btn-default importButton" data-format="latex"
         {...latexProps.buttonProps}>
          Import LaTeX
        </button>
        <button className="btn btn-danger superdeleteImportButton"
         onClick={onSuperdeleteImported}>
          Superdelete Imported
        </button>
      </>
    }
    <button className="btn btn-info downloadButton" onClick={onDownload}>
      Download ZIP
    </button>
  </div>
ImportExportButtons.displayName = 'ImportExportButtons'

export GroupTags = React.memo ({group}) ->
  tags = useTracker ->
    groupTags group
  , [group]
  <div className="groupTags">
    <TagList tags={tags} group={group}/>
  </div>
GroupTags.displayName = 'GroupTags'

memberLinks = (group, sortedMembers) ->
  escapedGroup = escapeGroup group
  count = 0
  for member in sortedMembers
    partial = member.rolesPartial?[escapedGroup]
    subtitle = null
    if partial?
      msgs = Messages.find _id: $in: (id for id of partial)
      .fetch()
      subtitle = "Access to: " + (
        for msg in msgs
          "“#{titleOrUntitled msg}”"
      ).join '; ' if msgs.length
    <React.Fragment key={member.username}>
      {', ' if count++}
      <UserLink user={member} group={group} subtitle={subtitle}/>
    </React.Fragment>

export GroupMembers = React.memo ({group}) ->
  members = useTracker ->
    full: memberLinks group, sortedGroupFullMembers group
    partial: memberLinks group, sortedGroupPartialMembers group
  , [group]

  <div className="members alert alert-info">
    <p>
      <b>{members.full.length} members of this group:</b>
    </p>
    <p>
      {if members.full.length
        members.full
      else
        '(none)'
      }
    </p>
    {if members.partial.length
      <>
        <hr/>
        <p>
          <b>{members.partial.length} with partial access to this group:</b>
        </p>
        <p>{members.partial}</p>
      </>
    }
  </div>
GroupMembers.displayName = 'GroupMembers'

export MessageShort = React.memo ({message}) ->
  messageLink = useMemo ->
    pathFor 'message',
      group: message.group
      message: message._id
  , [message]
  formattedTitle = useTracker ->
    formatTitleOrFilename message, bold: true
  , [message]
  creator = useTracker ->
    displayUser message.creator
  , [message.creator]
  emojiPositive = useTracker ->
    emojis = emojiReplies message, class: 'positive'
    count = 0
    for emoji in emojis
      count += emoji.who.length
    {count, emojis}
  , [message.emoji]
  subscribed = useTracker ->
    subscribedToMessage message
  , [message]

  onSubscribe = (e) ->
    e.preventDefault()
    e.stopPropagation()
    if subscribedToMessage message
      Meteor.users.update Meteor.userId(),
        $push: 'profile.notifications.unsubscribed': message._id
        $pull: 'profile.notifications.subscribed': message._id
    else
      Meteor.users.update Meteor.userId(),
        $push: 'profile.notifications.subscribed': message._id
        $pull: 'profile.notifications.unsubscribed': message._id

  <tr className="messageShort #{messageClass.call message}">
    <td className="title">
      <a href={messageLink}>
        <span dangerouslySetInnerHTML={__html: formattedTitle}/>
        <MessageTags message={message} noLink/>
        <MessageLabels message={message}/>
      </a>
    </td>
    <td className="author">
      <a href={messageLink}>{creator}</a>
    </td>
    <td>
      <a href={messageLink}>
        {if message.published
          <FormatDate date={message.published}/>
        else
          <FormatDate date={message.created}/>
        }
      </a>
    </td>
    <td>
      <a href={messageLink}>
        <FormatDate date={message.submessageLastUpdate}/>
      </a>
    </td>
    <td className="text-right">
      <a href={messageLink}>
        <span className="badge #{if message.submessageCount == 0 then 'badge-zero' else ''}">
          {message.submessageCount}
        </span>
      </a>
    </td>
    <td className="text-right">
      {if emojiPositive.count
        <OverlayTrigger flip overlay={(props) ->
          <Tooltip {...props}>
            {for emoji in emojiPositive.emojis
              <React.Fragment key={emoji.symbol}>
                {for user in emoji.who
                  <React.Fragment key={user}>
                    <span className="fas fa-#{emoji.symbol} #{emoji.class}"/>
                    {" #{displayUser user} "}
                  </React.Fragment>
                }
              </React.Fragment>
            }
          </Tooltip>
        }>
          <a href={messageLink}>
            <span className="badge badge-positive">
              {emojiPositive.count}
            </span>
          </a>
        </OverlayTrigger>
      }
    </td>
    <td className="subscribe text-center">
      <button className="btn btn-default btn-xs subscribe"
       onClick={onSubscribe}>
        {if subscribed
          <span className="fas fa-check"/>
        else
          <span className="fas fa-times"/>
        }
      </button>
    </td>
  </tr>
MessageShort.displayName = 'MessageShort'

Template.groupRename.events
  'click .groupRenameButton': (e, t) ->
    e.preventDefault()
    e.stopPropagation()
    groupOld = routeGroup()
    groupNew = t.find('#groupInput').value
    Modal.hide()
    return unless validGroup groupNew  ## ignore blank or otherwise invalid name
    Meteor.call 'groupRename', groupOld, groupNew, (error, result) ->
      if error
        console.error 'groupRename:', error
      else
        Router.go 'group',
          group: groupNew
  'click .cancelButton': (e) ->
    e.preventDefault()
    e.stopPropagation()
    Modal.hide()

Template.superdeleteImport.events
  'click .superdeleteImportConfirm': (e, t) ->
    e.preventDefault()
    e.stopPropagation()
    Modal.hide()
    console.log 'Loading all messages in group...'
    sub = Meteor.subscribe 'messages.imported', t.data.group, ->
      count = 0
      Messages.find
        group: t.data.group
        imported: $ne: null
      .forEach (msg) ->
        count += 1
        console.log 'Superdeleting', msg._id #, msg.title?[...20]
        Meteor.call 'messageSuperdelete', msg._id
      console.log 'Superdeleted', count, 'imported messages'
      sub.stop()
  'click .cancelButton': (e) ->
    e.preventDefault()
    e.stopPropagation()
    Modal.hide()

Template.downloadGroup.events
  'click .downloadConfirm': (e, t) ->
    e.preventDefault()
    e.stopPropagation()
    Modal.hide()
    import('/imports/download.coffee').then (d) => d.downloadGroup @group
  'click .cancelButton': (e) ->
    e.preventDefault()
    e.stopPropagation()
    Modal.hide()
