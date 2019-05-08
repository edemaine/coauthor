Template.author.onCreated ->
  setTitle "Author #{Template.currentData()?.author}"

Template.author.helpers
  messages: ->
    messagesBy @group, @author
  messageCountText: ->
    pluralize messagesBy(@group, @author).count(), 'message'
  wildLink: ->
    if @group != wildGroup
      pathFor 'author',
        group: wildGroupRoute
        author: @author
  displayUser: ->
    displayUser @author
  email: ->
    email = findUsername(@author)?.emails?[0]
    unless email
      'unspecified'
    else if email.verified
      "&lsquo;#{_.escape email.address}&rsquo;"
    else
      "&lsquo;#{_.escape email.address}&rsquo; unverified"
  fullMember: ->
    findUsername(@author)?.roles?[escapeGroup @group]?.length
  partialMember: ->
    not _.isEmpty findUsername(@author)?.rolesPartial?[escapeGroup @group]

Template.author.events
  'click .makePartialMember': (e, t) ->
    e.preventDefault()
    e.stopPropagation()
    group = t.data.group
    username = t.data.author
    user = findUsername username
    roles = user.roles?[escapeGroup @group]
    unless roles?.length
      throw new Error "#{username} has no full-member roles"
    console.log "Removing #{username}'s full-member roles: #{roles.join ', '}"
    roots =
      messagesBy(group, username).map (message) -> message2root message
    if roots.length
      roots = _.uniq roots.sort(), true
      console.log "Switching #{username}'s access to the following roots: #{roots.join ', '}"
      for root in roots
        for role in roles
          Meteor.call 'setRole', group, root, username, role, true
    for role in roles
      Meteor.call 'setRole', group, null, username, role, false
