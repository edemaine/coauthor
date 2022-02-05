import {createMemo, Show, For} from 'solid-js'
import {render} from 'solid-js/web'
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
            fallback="Global permissions for all groups">
        {'Permissions for '}
        <Show when={props.messageID?}>
          thread &ldquo;
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
        <For each={users()}>{(user) ->
          <ErrorBoundary>
            <User group={props.group} messageID={props.messageID} user={user} admin={admin()}/>
          </ErrorBoundary>
        }</For>
        <ErrorBoundary>
          <Anonymous group={props.group} messageID={props.messageID} admin={admin()}/>
        </ErrorBoundary>
        {###
        <Show when={props.group != wildGroup and not props.messageID?}>
          <ErrorBoundary>
            <UserInvitations group={props.group}/>
          </ErrorBoundary>
        </Show>
        ###}
      </tbody>
    </table>
  </ErrorBoundary>

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

window.benchmark = ->
  times =
    for i in [1..51]
      before = new Date
      dispose = render(<Users group={'bb29'}/>, document.body)
      after = new Date
      dispose()
      after - before
  total = 0
  total += time for time in times
  median = times[..].sort((x, y) -> x-y)[(times.length - 1)// 2]
  console.log "min=#{Math.min(...times)} mean=#{total / times.length} median=#{median} #{times.join ','}"

# full        min=449 mean=891 median=840 1062,1112,606,623,1050,1140,1136,874,858,449
# no left col min=186 mean=364 median=225 465,722,699,469,271,186,225,190,213,201
# no date     min=353 mean=551 median=475 985,494,353,967,539,408,475,493,392,405
# no name     min=445 mean=643 median=634 765,652,634,1216,752,536,671,493,445,449,461
# no link     min=388 mean=986 median=901 949,1036,1390,1956,1305,876,852,901,668,388,522

# full        min=373 mean=671 median=538 611,435,391,381,373,1330,939,1218,532,538,633
# no left col min=98 mean=271.8181818181818 median=120 145,116,120,110,98,106,115,293,815,732,340
# no date     min=158 mean=402.90909090909093 median=212 212,178,169,226,178,158,197,1051,782,617,664
# no name     min=298 mean=341.72727272727275 median=319 534,337,316,319,364,304,301,317,298,336,333
# no link     min=329 mean=389.1818181818182 median=373 401,373,353,431,501,347,455,342,329,386,363
# full        min=369 mean=423.1818181818182 median=389 571,389,389,379,369,380,435,369,591,399,384

# fix date    min=182 mean=197.36363636363637 median=193 226,213,211,193,187,186,183,208,183,182,199

# reactiveFix min=242 mean=359.47058823529414 median=309 439,372,450,1224,319,313,299,353,334,395,330,292,761,1043,386,272,260,242,284,301,346,343,360,301,296,283,371,396,292,309,306,305,333,380,306,264,335,298,278,257,269,252,274,307,340,326,293,311,343,298,292
# optimize    min=196 mean=297.45098039215685 median=256 274,245,273,217,295,1169,1002,733,268,222,230,218,263,275,216,241,354,268,211,207,227,196,208,299,312,278,359,312,265,251,272,377,357,311,372,220,256,205,208,221,197,211,215,212,216,210,208,222,258,263,271
# clean       min=171 mean=219.33333333333334 median=188 313,206,369,184,175,195,182,191,180,184,188,182,247,198,510,306,305,418,350,183,185,303,199,186,189,183,175,176,208,177,180,209,171,180,188,174,185,193,187,183,191,348,246,195,184,191,196,183,195,177,183
# min=188 mean=239 median=210 295,333,215,369,204,202,193,204,206,195,196,212,207,203,298,374,241,238,224,192,609,406,218,209,233,200,191,210,188,215,207,190,254,249,440,234,206,231,189,213,208,188,215,195,194,212,192,194,213,206,279