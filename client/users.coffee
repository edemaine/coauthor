### eslint-disable react/no-unknown-property ###
import {createMemo, createSignal, Show, For} from 'solid-js'
import {createFind, createFindOne, createTracker} from 'solid-meteor-data'
import Badge from 'solid-bootstrap/esm/Badge'
import Button from 'solid-bootstrap/esm/Button'
import ButtonGroup from 'solid-bootstrap/esm/ButtonGroup'

import {ErrorBoundary} from './solid/ErrorBoundary'
import {TextTooltip} from './solid/TextTooltip'
import {formatDate} from './lib/date'
import {allRoles, messagePartialMembers} from '/lib/groups'

Template.users.helpers
  Users: -> Users

export Users = (props) ->
  createTracker -> setTitle 'Users'
  admin = createTracker ->
    group: messageRoleCheck props.group, props.messageID, 'admin'
    wild: messageRoleCheck wildGroup, props.messageID, 'admin'
  [hasMessage, message] = createFindOne -> findMessage props.messageID
  messageTitle = createMemo ->
    titleOrUntitled if hasMessage() then message else title: '(loading)'
  fullMembers = createFind -> groupFullMembers props.group
  partialMembers = createFind ->
    if props.messageID?
      messagePartialMembers props.group, props.messageID
    else
      groupPartialMembers props.group
  isWild = -> props.group == wildGroup

  EditGroupPermissions = =>
    <Show when={props.messageID? and admin().group}>
      <a href={pathFor 'users', group: props.group} className="btn btn-warning">
        Edit Group Permissions
      </a>
    </Show>
  EditGlobalPermissions = =>
    <Show when={not isWild() and admin().wild}>
      <a href={pathFor 'users', group: wildGroup} className="btn btn-danger">
        Edit Global Permissions
      </a>
    </Show>

  <ErrorBoundary>
    <h2>
      <Show when={props.messageID? or not isWild()}
            fallback="GLOBAL permissions for ALL groups">
        {'Permissions for '}
        <Show when={props.messageID?}>
          THREAD &ldquo;
          <a href={pathFor 'message', {group: props.group, message: props.messageID}}>
            {messageTitle}
          </a>
          &rdquo;{' in '}
        </Show>
        <Show when={not isWild()} fallback="all groups">
          group &ldquo;
          <a href={pathFor 'group', group: props.group}>{props.group}</a>
          &rdquo;
        </Show>
      </Show>
      <div className="links btn-group pull-right">
        <EditGroupPermissions/>
        <EditGlobalPermissions/>
      </div>
    </h2>
    <Show when={props.messageID?}>
      <UserTable users={partialMembers()}
       group={props.group} messageID={props.messageID}
       admin={admin()} anonymous={props.messageID?}>
        Explicit permission to thread &ldquo;
        <a href={pathFor 'message', {group: props.group, message: props.messageID}}>
          {messageTitle}
        </a>
        &rdquo;:
      </UserTable>
    </Show>
    <UserTable users={fullMembers()}
     group={props.group} messageID={props.messageID}
     admin={admin()} anonymous={not props.messageID?}>
      <Show when={not isWild()} fallback="Global users">
        Full members of group &ldquo;
        <a href={pathFor 'group', group: props.group}>{props.group}</a>
        &rdquo;
        <Show when={props.messageID?}>
          {' can automatically access the thread'}
        </Show>
        :
      </Show>
      <div className="links btn-group pull-right">
        <EditGroupPermissions/>
      </div>
    </UserTable>
    <Show when={not isWild() and not props.messageID?}>
      <UserTable users={partialMembers()}
       group={props.group} messageID={props.messageID} admin={admin()}>
        Partial members of group &ldquo;
        <a href={pathFor 'group', group: props.group}>{props.group}</a>
        &rdquo;:
      </UserTable>
    </Show>
    <hr/>
    <UserSearch
       group={props.group} messageID={props.messageID} admin={admin()}/>
    {###
    <Show when={not isWild() and not props.messageID?}>
      <ErrorBoundary>
        <UserInvitations group={props.group}/>
      </ErrorBoundary>
    </Show>
    ###}
  </ErrorBoundary>

export UserSearch = (props) ->
  [limit, setLimit] = createSignal '10'
  parseLimit = ->
    parsed = Math.round parseFloat limit()
    parsed = undefined if isNaN parsed
    parsed
  [search, setSearch] = createSignal ''
  query = createMemo =>
    if (pattern = search())?
      pattern =
        $regex: escapeRegExp pattern
        $options: 'i'
      $or: [
        username: pattern
      ,
        'profile.fullname': pattern
      ,
        emails: $elemMatch: address: pattern
      ]
    else
      {}
  count = createTracker -> Meteor.users.find(query()).count()
  users = createFind ->
    Meteor.users.find query(),
      sort: [['createdAt', 'desc']]
      limit: parseLimit()
  #usersReverse = => [...users()].reverse()
  LimitInput = =>
    <input class="form-control input-sm limit" placeholder="all"
     type="number" value={limit()}
     onChange={(e) => setLimit e.currentTarget.value}/>
  MoreButton = =>
    <Button variant="success" size="sm"
     onClick={=> setLimit ((parseLimit() ? 0) + 10).toString()}>
      More
    </Button>
  AllButton = =>
    <Button variant="warning" size="sm" onClick={=> setLimit ''}
     disabled={not parseLimit()?}>
      All
    </Button>
  <>
    <h3 class="form-inline">
      <Badge bg="secondary">{count()}</Badge>
      {' All Coauthor users, limited to latest '}
      <div class="input-group">
        <LimitInput/>
        <span class="input-group-btn"><AllButton/></span>
        :
      </div>
    </h3>
    <div class="input-group">
      <input class="form-control" placeholder="Search" value={search()}
       onInput={(e) => setSearch e.currentTarget.value}/>
      <span class="input-group-btn">
        <Button variant="warning" onClick={=> setSearch ''}>Reset</Button>
      </span>
    </div>
    <p/>
    <UserTable users={users()} search={search()}
      group={props.group} messageID={props.messageID} admin={props.admin}/>
    <div class="form-inline">
      <LimitInput/>
      {' '}
      out of {count()} users shown
      {' '}
      <ButtonGroup>
        <MoreButton/>
        <AllButton/>
      </ButtonGroup>
    </div>
  </>

export UserTable = (props) -> <>
  {if props.children
    <>
      <hr/>
      <h3>
        <Badge bg="secondary">{props.users.length}</Badge>
        {' '}
        {props.children}
      </h3>
    </>
  }
  <table className="table table-striped table-hover users clearfix">
    <thead>
      <tr>
        <th className="user">User</th>
        <TextTooltip title="Permission to see the group at all, and read all messages within">
          <th className="text-help">Read</th>
        </TextTooltip>
        <TextTooltip title="Permission to post new messages and replies to the group, and to edit those authored messages">
          <th className="text-help">Post</th>
        </TextTooltip>
        <TextTooltip title="Permission to edit all messages, not just previously authored messages">
          <th className="text-help">Edit</th>
        </TextTooltip>
        <TextTooltip title="Permission to perform dangerous operations: history-destroying superdelete and XML import">
          <th className="text-help">Super</th>
        </TextTooltip>
        <TextTooltip title="Permission to administer other users in the group, i.e., to change their permissions">
          <th className="text-help">Admin</th>
        </TextTooltip>
      </tr>
    </thead>
    <tbody>
      <For each={props.users}>{(user) ->
        <ErrorBoundary>
          <User user={user} group={props.group} messageID={props.messageID} admin={props.admin} search={props.search}/>
        </ErrorBoundary>
      }</For>
      <Show when={props.anonymous}>
        <ErrorBoundary>
          <Anonymous group={props.group} messageID={props.messageID} admin={props.admin}/>
        </ErrorBoundary>
      </Show>
    </tbody>
  </table>
</>

onRole = (props, e) ->
  td = e.currentTarget.parentNode
  console.assert td.nodeName == 'TD'
  tr = td.parentNode
  console.assert tr.nodeName == 'TR'
  username = tr.getAttribute 'data-username'
  role = td.getAttribute 'data-role'
  old = e.currentTarget.innerText
  if 0 <= old.indexOf 'YES'
    Meteor.call 'setRole', props.group, props.messageID, username, role, false
  else if 0 <= old.indexOf 'NO'
    Meteor.call 'setRole', props.group, props.messageID, username, role, true
  else
    console.error "Unrecognized state: #{old}"

export User = (props) ->
  escapedGroup = createMemo => escapeGroup props.group
  partialMember = createTracker =>
    return if props.messageID?
    ids = (id for id of props.user.rolesPartial?[escapedGroup()])
    return unless ids.length
    for id in ids
      Messages.findOne(id) ?
        _id: id
        title: '(loading)'
  roles = createMemo =>
    message = props.user.rolesPartial?[escapedGroup()]?[props.messageID] ? [] \
      if props.messageID?
    group = props.user.roles?[escapedGroup()] ? []
    global = props.user.roles?[wildGroup] ? [] if props.group != wildGroup
    first = message ? group
    {message, group, global, first}
  levels = {}
  for role in allRoles  ### eslint-disable-line coffee/no-unused-vars ###
    do (role) =>
      levels[role] = createMemo =>
        r = roles()
        l = []
        l.push role in r.message if r.message?
        l.push role in r.group if r.group?
        l.push role in r.global if r.global?
        l.pop() until l.length <= 1 or l[l.length-1]
        l
  authorLink = -> pathFor 'author',
    group: props.group
    author: props.user.username
  regExp = createMemo ->
    new RegExp escapeRegExp(props.search), 'ig' if props.search
  Highlight = (props) =>
    <Show when={regExp()} fallback={props.text}>
      <span innerHTML={
        _.escape props.text
        .replace regExp(), '<span class="highlight">$&</span>'
      }/>
    </Show>

  <>
    <tr data-username={props.user.username}>
      <td className="user">
        <span className="name">
          {if fullname = props.user.profile?.fullname 
            <Highlight text={fullname + ' = '}/>
          }
          <a href={authorLink()}>@{props.user.username}</a>
        </span>
        <span className="email">
          {if email = props.user.emails?[0]
            <Highlight text=" (#{email.address}#{if email.verified then '' else ', unverified'})"/>
          else
            ' (no email)'
          }
        </span>
        <div className="createdAt">
          joined {formatDate props.user.createdAt}
        </div>
      </td>
      <For each={allRoles}>{(role) =>
        showLevel = (i) ->
          l = levels[role]()
          return if i >= l.length
          level = if l[i] then 'YES' else 'NO'
          level += '*' if i == 1 + props.messageID?  # global override
          if i == l.length - 1  # last level
            if i == 0
              level
            else
              <b>{level}</b>
          else
            <del>{level}</del>
        <td data-role={role}>
          {if props.admin.group
            <button className="roleButton btn #{if levels[role]()[0] then 'btn-success' else 'btn-danger'}"
             onClick={[onRole, props]}>
              {showLevel 0}
            </button>
          else
            showLevel 0
          }
          {showLevel 1}
          {showLevel 2}
        </td>
      }</For>
    </tr>
    <Show when={partialMember()?.length}>
      {### Extra row to get parity right ###}
      <tr className="partialMemberSep"/>
      <tr className="partialMember">
        <td colSpan="6">
          <span className="fa fa-id-card" aria-hidden="true"/>
          {" Partial access to messages:"}
          <For each={partialMember()}>{(message) ->
            <>
              {" • "}
              <a href={pathFor 'users.message', {group: props.group, message: message._id}}>
                {titleOrUntitled message}
              </a>
            </>
          }</For>
        </td>
      </tr>
    </Show>
  </>

export Anonymous = (props) ->
  roles = createTracker -> groupAnonymousRoles props.group
  disabled = createMemo ->
    if props.group == wildGroup
      'Cannot give anonymous access to all groups globally'
    else if props.messageID?
      'Cannot give anonymous access to individual threads'
    else if not props.admin.wild
      'Need global administrator privileges to change anonymous access'

  <tr data-username="*">
    <td className="user">
      <i>&lt;anonymous&gt;</i>
    </td>
    <For each={allRoles}>{(role) ->
      btnclass = -> if role in roles() then 'btn-success' else 'btn-danger'
      level = -> if role in roles() then 'YES' else 'NO'
      button = ->
        <td data-role={role}>
          <Show when={props.admin.group} fallback={-> level()}>
            <button className="roleButton btn #{btnclass()}#{if disabled() then ' disabled' else ''}"
            disabled={Boolean disabled()} onClick={[onRole, props]}>
              {level()}
            </button>
          </Show>
        </td>
      <Show when={props.admin.group and disabled()} fallback={-> button()}>
        <TextTooltip title={disabled()}>
          <td data-role={role}>
            {button()}
          </td>
        </TextTooltip>
      </Show>
    }</For>
  </tr>

###
UserInvitations = React.memo ({group}) ->
  invitations = useTracker ->
    Groups.findOne
      name: group
    ?.invitations ? []
  , [group]
  <>
    <tr>
      <td colSpan="6">
        <input type="text" size="40" rows="3" id="invitationInput"/>
        <button className="invitationButton btn btn-warning">
          Invite Users via Email
        </button>
      </td>
    </tr>
    {for invitation in invitations
      <tr key={invitation.email} data-email={invitation.email}>
        <th>{invitation.email}</th>
        <td data-role="read">...</td>
        <td data-role="post">...</td>
        <td data-role="edit">...</td>
        <td data-role="super">...</td>
        <td data-role="admin">...</td>
      </tr>
    }
  </>
###
