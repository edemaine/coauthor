Template.search.onCreated ->
  @autorun ->
    setTitle "Search #{Template.currentData()?.search}"

messagesSearch = (group, search) ->
  Messages.find
    $and: [
      group: group
      parseSearch search
    ]

topMessagesSearch = (group, search) ->
  msgs = messagesSearch group, search
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
    msg.readChildren = (byId[child] for child in msg.children when child of byId)
  ## Return the messages that are not children within the set
  for msg in msgs
    for child in msg.readChildren
      delete byId[child._id]
  msg for msg in msgs when msg._id of byId
  #groups = _.groupBy msgs, (msg) ->
  #pairs = _.pairs groups
  #pairs.sort()
  #for pair in pairs

Template.search.helpers
  messages: ->
    topMessagesSearch @group, @search
  messageCountText: ->
    pluralize messagesSearch(@group, @search).count(), 'message'
  messageCount: ->
    messagesSearch(@group, @search).count()
  valid: ->
    parseSearch(@search)?
  formatSearch: ->
    formatSearch @search

Template.search.events
  'change #searchInput': (e, t) ->
    Router.go 'search',
      group: @group
      search: t.find('#searchInput').value
  'submit form': (e, t) ->
    e.preventDefault()
