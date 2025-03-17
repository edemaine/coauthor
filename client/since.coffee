import {formatDate} from './lib/date'
import {groupDefaultSort} from '/lib/groups'
import {findMessageRoot, messagesSortedBy, parseSince, restrictChildren} from '/lib/messages'

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
  ## Middle significant: cluster by thread (root) id
  msgs = _.sortBy msgs, (msg) -> msg.root ? msg._id
  ## Middle significant: sort roots before their descendants
  msgs = _.sortBy msgs, (msg) -> msg.root?
  ## Most significant: sort by group's default sort order --
  ## applying sort to message root, not the message
  msgs = messagesSortedBy msgs, groupDefaultSort(group), findMessageRoot
  ## Restrict children pointers to within match and avoid duplicates
  restrictChildren msgs

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
