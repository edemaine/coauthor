import {groupDefaultSort} from '/lib/groups'
import {findMessageRoot, messagesSortedBy, restrictChildren} from '/lib/messages'
import {formatSearch, parseSearch} from '/lib/search'

Template.search.onCreated ->
  @autorun ->
    setTitle "Search #{Template.currentData()?.search}"

messagesSearch = (group, search) ->
  query = parseSearch search, group
  return unless query?
  if group != wildGroup
    query = $and: [
      group: group
      query
    ]
  Messages.find query

topMessagesSearch = (group, search) ->
  msgs = messagesSearch group, search
  return [] unless msgs?
  ## Least significant: sort by increasing creation time
  msgs = msgs.fetch()
  ## Middle significant: sort roots before their descendants
  msgs = _.sortBy msgs, (msg) -> msg.root?
  ## Most significant: sort by group's default sort order --
  ## applying sort to message root, not the message
  msgs = messagesSortedBy msgs, groupDefaultSort(group), findMessageRoot
  ## Mostest significant: sort by group name
  msgs = _.sortBy msgs, 'group'
  ## Restrict children pointers to within match and avoid duplicates
  msgs = restrictChildren msgs
  ## Set `newGroup` for group headers
  lastGroup = null
  for msg in msgs
    if lastGroup != msg.group
      msg.newGroup = lastGroup = msg.group
  msgs

Template.search.helpers
  messages: ->
    topMessagesSearch @group, @search
  messageCountText: ->
    pluralize messagesSearch(@group, @search)?.count() ? 0, 'message'
  messageCount: ->
    messagesSearch(@group, @search)?.count() ? 0
  valid: ->
    parseSearch(@search)?
  formatSearch: ->
    formatSearch @search, @group
