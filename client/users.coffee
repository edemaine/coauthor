haveRole = (role, roles) ->
  group = routeGroup()
  if role in (roles?[group] ? [])
    btnclass = 'success'
    local = 'YES'
  else
    btnclass = 'danger'
    local = 'NO'
  global = ''
  if group != wildGroup
    if role in (roles?[wildGroup] ? [])
      local = "<del>#{local}</del>"
      global = ' <b class="text-success space">YES*</b>'
    #else
    #  global = 'NO*'
  if groupRoleCheck group, 'admin'
    local = "<button class='roleButton btn btn-#{btnclass}'>#{local}</button>"
  local + global

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

Template.users.helpers
  users: ->
    Meteor.users.find()
  showAnonymous: ->
    @group != wildGroup

  readRole: -> haveRole 'read', @roles
  postRole: -> haveRole 'post', @roles
  editRole: -> haveRole 'edit', @roles
  superRole: -> haveRole 'super', @roles
  adminRole: -> haveRole 'admin', @roles

  anonReadRole: -> anonRole 'read', @group
  anonPostRole: -> anonRole 'post', @group
  anonEditRole: -> anonRole 'edit', @group
  anonSuperRole: -> anonRole 'super', @group
  anonAdminRole: -> anonRole 'admin', @group

  wildLink: -> @group != wildGroup and groupRoleCheck wildGroup, 'admin'

Template.users.events
  'click .globalUsersButton': (e) ->
    e.preventDefault()
    e.stopPropagation()
    Router.go 'users', group: wildGroupRoute

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
      Meteor.call 'setRole', t.data.group, username, role, false
    else if 0 <= old.indexOf 'NO'
      Meteor.call 'setRole', t.data.group, username, role, true
