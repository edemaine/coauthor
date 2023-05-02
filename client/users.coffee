import {createMemo, Show, For} from 'solid-js'
import {createFind, createFindOne, createTracker} from 'solid-meteor-data'

import {ErrorBoundary} from './solid/ErrorBoundary'
import {TextTooltip} from './solid/TextTooltip'
import {formatDate} from './lib/date'
import {allRoles} from '/lib/groups'

Template.users.helpers
  Users: -> Users

export Users = (props) ->
  createTracker -> setTitle 'Users'
  admin = createTracker ->
    group: messageRoleCheck props.group, props.messageID, 'admin'
    wild: messageRoleCheck wildGroup, props.messageID, 'admin'
  [hasMessage, message] = createFindOne -> findMessage props.messageID
  users = createFind ->
    Meteor.users.find {},
      sort: [['createdAt', 'asc']]

  <ErrorBoundary>
    <h3>
      <Show when={props.messageID? or props.group != wildGroup}
            fallback="GLOBAL permissions for ALL groups">
        {'Permissions for '}
        <Show when={props.messageID?}>
          THREAD &ldquo;
          <a href={pathFor 'message', {group: props.group, message: props.messageID}}>
            {titleOrUntitled if hasMessage() then message else title: '(loading)'}
          </a>
          &rdquo;{' in '}
        </Show>
        <Show when={props.group != wildGroup} fallback="all groups">
          group &ldquo;
          <a href={pathFor 'group', group: props.group}>{props.group}</a>
          &rdquo;
        </Show>
      </Show>
      <div className="links btn-group pull-right">
        <Show when={props.messageID? and admin().group}>
          <a href={pathFor 'users', group: props.group} className="btn btn-warning">
            Edit Group Permissions
          </a>
        </Show>
        <Show when={props.group != wildGroup and admin().wild}>
          <a href={pathFor 'users', group: wildGroup} className="btn btn-danger">
            Edit Global Permissions
          </a>
        </Show>
      </div>
    </h3>
    <UserTable group={props.group} messageID={props.messageID}
     users={users()} admin={admin()} anonymous/>
    {###
    <Show when={props.group != wildGroup and not props.messageID?}>
      <ErrorBoundary>
        <UserInvitations group={props.group}/>
      </ErrorBoundary>
    </Show>
    ###}
  </ErrorBoundary>

export UserTable = (props) ->
  <table className="table table-striped table-hover users clearfix">
    <thead>
      <tr>
        <th>Username</th>
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
          <User group={props.group} messageID={props.messageID} user={user} admin={props.admin}/>
        </ErrorBoundary>
      }</For>
      <Show when={props.anonymous}>
        <ErrorBoundary>
          <Anonymous group={props.group} messageID={props.messageID} admin={props.admin}/>
        </ErrorBoundary>
      </Show>
    </tbody>
  </table>

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
  escapedGroup = createMemo -> escapeGroup props.group
  partialMember = createTracker ->
    return if props.messageID?
    ids = (id for id of props.user.rolesPartial?[escapedGroup()])
    return unless ids.length
    for id in ids
      Messages.findOne(id) ?
        _id: id
        title: '(loading)'
  roles = createMemo ->
    message = props.user.rolesPartial?[escapedGroup()]?[props.messageID] ? [] \
      if props.messageID?
    group = props.user.roles?[escapedGroup()] ? []
    global = props.user.roles?[wildGroup] ? [] if props.group != wildGroup
    first = message ? group
    {message, group, global, first}
  authorLink = -> pathFor 'author',
    group: props.group
    author: props.user.username

  <>
    <tr data-username={props.user.username}>
      <th>
        <div className="name">
          {if (fullname = props.user.profile?.fullname)
            "#{fullname} ("
          }
          <a href={authorLink()}>{props.user.username}</a>
          {', '}
          {if (email = props.user.emails?[0])?
            email.address +
            if email.verified then '' else ' (unverified)'
          else
            'no email'
          }
          {')' if props.user.profile?.fullname}
        </div>
        <div className="createdAt">
          joined {formatDate props.user.createdAt}
        </div>
      </th>
      {
      r = roles()
      for role in allRoles
        levels = []
        levels.push role in r.message if r.message?
        levels.push role in r.group if r.group?
        levels.push role in r.global if r.global?
        levels.pop() until levels.length == 1 or levels[levels.length-1]
        showLevel = (i) ->
          return if i >= levels.length
          level = if levels[i] then 'YES' else 'NO'
          level += '*' if i == 1 + props.messageID?  # global override
          space = if i == 0 then '' else 'space'
          if i == levels.length - 1  # last level
            if i == 0
              level
            else
              <b className={space}>{level}</b>
          else
            <del className={space}>{level}</del>
        <td data-role={role}>
          {if props.admin.group
            <button className="roleButton btn #{if levels[0] then 'btn-success' else 'btn-danger'}"
             onClick={[onRole, props]}>
              {showLevel 0}
            </button>
          else
            showLevel 0
          }
          {showLevel 1}
          {showLevel 2}
        </td>
      }
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
    <th>
      <i>&lt;anonymous&gt;</i>
    </th>
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
