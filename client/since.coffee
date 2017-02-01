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
  ## xxx should use default sort, not title sort?
  msgs = _.sortBy msgs, (msg) ->
    if msg.root
      titleSort (Messages.findOne(msg.root)?.title ? '')
    else
      titleSort msg.title
  ## Form a set of all message IDs in match
  byId = {}
  for msg in msgs
    byId[msg._id] = msg
  ## Restrict children pointers to within match
  for msg in msgs
    msg.readChildren = (child for child in msg.children when child of byId)
  ## Return the messages that are not children within the set
  for msg in msgs
    for child in msg.readChildren
      delete byId[child]
  msg for msg in msgs when msg._id of byId
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
