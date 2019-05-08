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
