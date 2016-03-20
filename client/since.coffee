parseSince = (since) ->
  try
    match = /^\s*[+-]?\s*(\d+)\s*(\w+)\s*$/.exec since
    if match?
      moment().subtract(match[1], match[2]).toDate()
    else
      match = /^\s*(\d+)\s*:\s*(\d+)\s*$/.exec since
      if match?
        d = moment().hour(match[1]).minute(match[2])
        if moment().diff(d) < 0
          d = d.subtract(1, 'day')
        d.toDate()
      else
        moment(since).toDate()
  catch
    null

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
    messagesSince(@group, @since).length
  valid: ->
    parseSince(@since)?

Template.since.events
  'change #sinceInput': (e, t) ->
    Router.go 'since',
      group: @group
      since: t.find('#sinceInput').value
  'submit form': (e, t) ->
    e.preventDefault()
