haveRole = (role, profile) ->
  group = routeGroup()
  message = routeMessage()
  levels = []
  if message
    have = role in (profile.rolesPartial?[escapeGroup group]?[message] ? [])
  else
    have = role in (profile.roles?[escapeGroup group] ? [])
  if have
    btnclass = 'success'
    levels.push 'YES'
  else
    btnclass = 'danger'
    levels.push 'NO'
  if message and role in (profile.roles?[escapeGroup group] ? [])
    levels.push "<del>#{levels.pop()}</del>"
    levels.push '<b class="text-success space">YES</b>'
  if group != wildGroup and role in (profile.roles?[wildGroup] ? [])
    levels.push "<del>#{levels.pop()}</del>"
    levels.push '<b class="text-success space">YES*</b>'
  if messageRoleCheck group, message, 'admin'
    levels[0] = "<button class='roleButton btn btn-#{btnclass}'>#{levels[0]}</button>"
  levels.join ' '

anonRole = (role, group) ->
  roles = groupAnonymousRoles group
  if role in roles
    btnclass = 'success'
    local = 'YES'
  else
    btnclass = 'danger'
    local = 'NO'
  if groupRoleCheck group, 'admin'
    local = "<button class='roleButton btn btn-#{btnclass}'>#{local}</button>"
  local

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

  readRole: -> haveRole 'read', @
  postRole: -> haveRole 'post', @
  editRole: -> haveRole 'edit', @
  superRole: -> haveRole 'super', @
  adminRole: -> haveRole 'admin', @

  anonReadRole: -> anonRole 'read', @group
  anonPostRole: -> anonRole 'post', @group
  anonEditRole: -> anonRole 'edit', @group
  anonSuperRole: -> anonRole 'super', @group
  anonAdminRole: -> anonRole 'admin', @group

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
  $('[data-toggle="tooltip"]').tooltip()
