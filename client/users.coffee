import React, {useEffect} from 'react'
import {useTracker} from 'meteor/react-meteor-data'

import {ErrorBoundary} from './ErrorBoundary'
import {TextTooltip} from './lib/tooltip'
import {formatDate} from './lib/date'
import {allRoles} from '/lib/groups'

Template.users.helpers
  Users: -> Users

export Users = React.memo ({group, messageID}) ->
  useEffect ->
    setTitle 'Users'
    undefined
  , []
  admin = useTracker ->
    group: messageRoleCheck group, messageID, 'admin'
    wild: messageRoleCheck wildGroup, messageID, 'admin'
  , [group, messageID]
  message = useTracker ->
    Messages.findOne messageID
  , [messageID]
  users = useTracker ->
    Meteor.users.find {},
      sort: [['createdAt', 'asc']]
    .fetch()
  , []

  <ErrorBoundary>
    <h3>
      {if messageID?
        <>
          Permissions for thread &ldquo;
          <a href={pathFor 'message', {group: group, message: messageID}}>
            {titleOrUntitled message ? title: '(loading)'}
          </a>
          &rdquo; in group &ldquo;
          <a href={pathFor 'group', group: group}>{group}</a>
          &rdquo;
        </>
      else if group == wildGroup
        "Global permissions for all groups"
      else
        <>
          Permissions for group &ldquo;
          <a href={pathFor 'group', group: group}>{group}</a>
          &rdquo;
        </>
      }
      <div className="links btn-group pull-right">
        {if messageID? and admin.group
          <a href={pathFor 'users', group: group} className="btn btn-warning">
            Edit Group Permissions
          </a>
        }
        {if group != wildGroup and admin.wild
          <a href={pathFor 'users', group: wildGroup} className="btn btn-danger">
            Edit Global Permissions
          </a>
        }
      </div>
    </h3>
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
        {for user in users
          <ErrorBoundary key={user.username}>
            <User group={group} messageID={messageID} user={user} admin={admin}/>
          </ErrorBoundary>
        }
        <ErrorBoundary>
          <Anonymous group={group} messageID={messageID} admin={admin}/>
        </ErrorBoundary>
        {###
        if group != wildGroup and not messageID?
          <ErrorBoundary>
            <UserInvitations group={group}/>
          </ErrorBoundary>
        ###}
      </tbody>
    </table>
  </ErrorBoundary>
Users.displayName = 'Users'

onRole = (group, messageID) -> (e) ->
  td = e.currentTarget.parentNode
  console.assert td.nodeName == 'TD'
  tr = td.parentNode
  console.assert tr.nodeName == 'TR'
  username = tr.getAttribute 'data-username'
  role = td.getAttribute 'data-role'
  old = e.currentTarget.innerText
  if 0 <= old.indexOf 'YES'
    Meteor.call 'setRole', group, messageID, username, role, false
  else if 0 <= old.indexOf 'NO'
    Meteor.call 'setRole', group, messageID, username, role, true
  else
    console.error "Unrecognized state: #{old}"

User = React.memo ({group, messageID, user, admin}) ->
  escapedGroup = escapeGroup group
  unless messageID?  # should not change
    partialMember = useTracker ->
      return if _.isEmpty user.rolesPartial?[escapedGroup]
      for id of user.rolesPartial[escapedGroup]
        Messages.findOne(id) ?
          _id: id
          title: '(loading)'
    , [user]
  authorLink = pathFor 'author',
    group: group
    author: user.username

  <>
    <tr data-username={user.username}>
      <th>
        <div className="name">
          {if fullname = user.profile?.fullname
            "#{fullname} ("
          }
          <a href={authorLink}>{user.username}</a>
          {', '}
          {if email = user.emails?[0]
            <>
              {email.address}
              {unless email.verified
                " unverified"
              }
            </>
          else
            "no email"
          }
          {if fullname
            ")"
          }
        </div>
        <div className="createdAt">
          joined {formatDate user.createdAt}
        </div>
      </th>
      {for role in allRoles
        levels = []
        if messageID?
          have = role in (user.rolesPartial?[escapedGroup]?[messageID] ? [])
        else
          have = role in (user.roles?[escapedGroup] ? [])
        if have
          btnclass = 'btn-success'
          levels.push 'YES'
        else
          btnclass = 'btn-danger'
          levels.push 'NO'
        if messageID? and role in (user.roles?[escapedGroup] ? [])
          levels.push 'YES'
        if group != wildGroup and role in (user.roles?[wildGroup] ? [])
          levels.push 'YES*'
        if levels.length > 1
          levels[0] = <del>{levels[0]}</del>
          if levels.length > 2
            levels[1] = <del className="text-success space">{levels[1]}</del>
          levels[levels.length-1] = <b className="text-success space">{levels[levels.length-1]}</b>
        for i in [0...levels.length-1]
          levels[i] = <del>{levels[i]}</del>
        <td key={role} data-role={role}>
          {if admin.group
            <button className="roleButton btn #{btnclass}"
             onClick={onRole group, messageID}>
              {levels[0]}
            </button>
          else
            levels[0]
          }
          {levels[1]}
          {levels[2]}
        </td>
      }
    </tr>
    {if partialMember?.length
      ## Extra row to get parity right
      <>
        <tr className="partialMemberSep"/>
        <tr className="partialMember">
          <td colSpan="6">
            <span className="fa fa-id-card" aria-hidden="true"/>
            {" Partial access to messages:"}
            {for message in partialMember
              <React.Fragment key={message._id}>
                {" • "}
                <a href={pathFor 'users.message', {group: group, message: message._id}}>
                  {titleOrUntitled message}
                </a>
              </React.Fragment>
            }
          </td>
        </tr>
      </>
    }
  </>
User.displayName = 'User'

export Anonymous = React.memo ({group, messageID, admin}) ->
  roles = useTracker ->
    groupAnonymousRoles group
  , [group]
  if group == wildGroup or messageID? or not admin.wild
    disabled = 'disabled'
    if group == wildGroup
      title = 'Cannot give anonymous access to all groups globally'
    else if messageID?
      title = 'Cannot give anonymous access to individual threads'
    else if not admin.wild
      title = 'Need global administrator privileges to change anonymous access'

  <tr data-username="*">
    <th>
      <i>&lt;anonymous&gt;</i>
    </th>
    {for role in allRoles
      if role in roles
        btnclass = 'btn-success'
        level = 'YES'
      else
        btnclass = 'btn-danger'
        level = 'NO'
      button =
        if admin.group
          <button className="roleButton btn #{btnclass} #{disabled ? ''}"
           disabled={disabled} onClick={onRole group, messageID}>
            {level}
          </button>
        else
          level
      if admin.group and title?
        <TextTooltip key={role} title={title}>
          <td data-role={role}>
            {button}
          </td>
        </TextTooltip>
      else
        <td key={role} data-role={role}>
          {button}
        </td>
    }
  </tr>
Anonymous.displayName = 'Anonymous'

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
UserInvitations.displayName = 'UserInvitations'
###
