Template.users.onCreated ->
  @autorun ->
    setTitle 'Users'

Template.users.helpers
  users: ->
    Meteor.users.find {},
      sort: [['createdAt', 'asc']]
  fullname: -> @profile?.fullname
  email: ->
    email = @emails?[0]
    unless email
      'no email'
    else if email.verified
      email.address
    else
      "#{email.address} unverified"
  showAnonymous: ->
    @group != wildGroup
  showInvitations: ->
    @group != wildGroup and false ## xxx disabled for now
  invitations: ->
    Groups.findOne
      name: @group
    ?.invitations ? []

  messageData: ->
    findMessage @message
  partialMember: ->
    return if routeMessage()
    return if _.isEmpty @rolesPartial?[escapeGroup routeGroup()]
    Messages.find
      _id: $in:
        (message for message, roles of @rolesPartial[escapeGroup routeGroup()])

  roles: ->
    group = routeGroup()
    escaped = escapeGroup group
    message = routeMessage()
    admin = messageRoleCheck group, message, 'admin'
    for role in allRoles
      levels = []
      if message
        have = role in (@rolesPartial?[escaped]?[message] ? [])
      else
        have = role in (@roles?[escaped] ? [])
      if have
        btnclass = 'btn-success' if admin
        levels.push 'YES'
      else
        btnclass = 'btn-danger' if admin
        levels.push 'NO'
      if message and role in (@roles?[escaped] ? [])
        levels.push 'YES'
      if group != wildGroup and role in (@roles?[wildGroup] ? [])
        levels.push 'YES*'
      {role, btnclass, level0: levels[0], level1: levels[1], level2: levels[2]}

  anonRoles: ->
    group = routeGroup()
    message = routeMessage()
    admin = messageRoleCheck group, message, 'admin'
    roles = groupAnonymousRoles group
    for role in allRoles
      if role in roles
        btnclass = 'btn-success' if admin
        level0 = 'YES'
      else
        btnclass = 'btn-danger' if admin
        level0 = 'NO'
      {role, btnclass, level0}

  groupLink: -> @message and groupRoleCheck @group, 'admin'
  wild: -> @group == wildGroup
  wildLink: ->
    if @group != wildGroup and groupRoleCheck wildGroup, 'admin'
      pathFor 'users', group: wildGroupRoute
    else
      null

Template.users.events
  'click .roleButton': (e, t) ->
    td = e.target
    while td.nodeName.toLowerCase() != 'td'
      td = td.parentNode
    tr = td
    while tr.nodeName.toLowerCase() != 'tr'
      tr = tr.parentNode
    username = tr.getAttribute 'data-username'
    role = td.getAttribute 'data-role'
    old = e.target.innerHTML
    if 0 <= old.indexOf 'YES'
      Meteor.call 'setRole', t.data.group, t.data.message, username, role, false
    else if 0 <= old.indexOf 'NO'
      Meteor.call 'setRole', t.data.group, t.data.message, username, role, true

  'click .invitationButton': (e, t) ->
    console.log t.find('#invitationInput').value
    ## xxx Meteor.call ...

Template.users.onRendered ->
  tooltipInit()
