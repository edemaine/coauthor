Template.author.onCreated ->
  setTitle "Author #{Template.currentData()?.author}"

Template.author.helpers
  messages: ->
    messagesBy @group, @author
  messageCount: ->
    pluralize messagesBy(@group, @author).fetch().length, 'message'
  wildLink: ->
    if @group != wildGroup
      pathFor 'author',
        group: wildGroupRoute
        author: @author
