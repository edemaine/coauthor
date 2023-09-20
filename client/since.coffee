import {formatDate} from './lib/date'
import {groupDefaultSort} from '/lib/groups'
import {findMessageRoot, messagesSortedBy, parseSince} from '/lib/messages'

Template.since.onCreated ->
  @autorun ->
    setTitle "Since #{Template.currentData()?.since}"

messagesSince = (group, since) ->
  Messages.find
    group: group
    updated: $gte: parseSince since
    published: $ne: false
    deleted: false
    private: $ne: true
  ,
    sort: [['created', 'asc']]

topMessagesSince = (group, since) ->
  #console.log parseSince since
  ## Least significant: sort by increasing creation time
  msgs = messagesSince group, since
  .fetch()
  ## Then sort by group's default sort order
  defaultSort = groupDefaultSort group
  ## ...after sorting roots before their descendants
  defaultSort.push
    key: 'root'
    reversed: true
  ## ...applying sort to message root, not the message
  msgs = messagesSortedBy msgs, defaultSort, (keyOf) -> (msg) ->
    keyOf findMessageRoot msg
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

Template.since.helpers
  messages: ->
    topMessagesSince @group, @since
  messageCount: ->
    pluralize messagesSince(@group, @since).count(), 'message'
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
