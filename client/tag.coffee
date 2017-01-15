Template.tag.onCreated ->
  setTitle "Tag #{Template.currentData()?.tag}"

messagesTagged = (group, tag) ->
  query =
    group: group
    "tags.#{escapeTag tag}": $exists: true
    published: $ne: false
    deleted: false
  if group == wildGroup
    delete query.group
  Messages.find query,
    sort: [['updated', 'desc']]
    #limit: parseInt(@limit)

Template.tag.helpers
  messages: ->
    messagesTagged @group, @tag
  messageCount: ->
    pluralize messagesTagged(@group, @tag).fetch().length, 'message'
  wildLink: ->
    if @group != wildGroup
      pathFor 'tag',
        group: wildGroupRoute
        tag: @tag
