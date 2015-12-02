haveRole = (role, roles) ->
  group = routeGroup()
  if group == wildGroupRoute
    group = wildGroup
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
      global = ' YES*'
    #else
    #  global = 'NO*'
  if groupRoleCheck group, 'admin'
    local = "<button class='roleButton btn btn-#{btnclass}'>#{local}</button>"
  local + global

Template.users.helpers
  users: ->
    Meteor.users.find()

  readRole: -> haveRole 'read', @roles
  postRole: -> haveRole 'post', @roles
  editRole: -> haveRole 'edit', @roles
  superRole: -> haveRole 'super', @roles
  adminRole: -> haveRole 'admin', @roles

  anonReadRole: -> haveRole 'read', groupAnonymousRoles @group
  anonPostRole: -> haveRole 'post', groupAnonymousRoles @group
  anonEditRole: -> haveRole 'edit', groupAnonymousRoles @group
  anonSuperRole: -> haveRole 'super', groupAnonymousRoles @group
  anonAdminRole: -> haveRole 'admin', groupAnonymousRoles @group

  wildLink: -> groupRoleCheck '*', 'admin'

Template.users.events
  'click .globalUsersButton': (e) ->
    e.preventDefault()
    e.stopPropagation()
    Router.go 'users', group: wildGroupRoute
