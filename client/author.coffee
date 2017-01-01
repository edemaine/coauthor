messagesBy = (group, author) ->
  query =
    group: group
    "authors.#{escapeUser author}": $exists: true
    published: $ne: false
    deleted: false
  if group == wildGroup
    delete query.group
  Messages.find query,
    sort: [['updated', 'desc']]
    #limit: parseInt(@limit)

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
