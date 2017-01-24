Template.tag.onCreated ->
  setTitle "Tag #{Template.currentData()?.tag}"

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
