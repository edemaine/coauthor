Template.since.onCreated ->
  @autorun ->
    setTitle "Since #{Template.currentData()?.since}"

messagesSince = (group, since) ->
  #console.log parseSince since
  msgs = Messages.find
    group: group
    updated: $gte: parseSince since
    published: $ne: false
    deleted: false
  ,
    sort: [['updated', 'asc']]
  .fetch()
  _.sortBy msgs, (msg) ->
    if msg.root
      titleSort (Messages.findOne(msg.root)?.title ? '')
    else
      titleSort msg.title
  #groups = _.groupBy msgs, (msg) ->
  #pairs = _.pairs groups
  #pairs.sort()
  #for pair in pairs

Template.since.helpers
  messages: ->
    messagesSince @group, @since
  messageCount: ->
    pluralize messagesSince(@group, @since).length, 'message'
  valid: ->
    parseSince(@since)?
  parseSince: ->
    formatDate parseSince @since

Template.since.events
  'change #sinceInput': (e, t) ->
    Router.go 'since',
      group: @group
      since: t.find('#sinceInput').value
  'submit form': (e, t) ->
    e.preventDefault()
