import {check} from 'meteor/check'
import {Mongo} from 'meteor/mongo'

import {escapeKey, unescapeKey, validKey} from './escape'

@Tags = new Mongo.Collection 'tags'

if Meteor.isServer
  Tags.createIndex [['group', 1], ['deleted', 1]]

@escapeTag = escapeKey
@unescapeTag = unescapeKey
@validTag = (tag) ->
  validKey(tag) and tag.trim().length > 0

@sortTags = (tags) ->
  return [] unless tags
  keys = _.keys tags
  keys.sort()
  for key in keys
    key: unescapeTag key
    value: tags[key]

@groupTags = (group) ->
  tags = Tags.find
    group: group
    deleted: false
  .fetch()
  _.sortBy tags, 'key'

## Currently, tags just map keys to "true".
## In the future, there will be other values, checked here.  (See #86.)
@validTags = (tags) ->
  for key, value of tags
    unless validTag(key) and value == true
      return false
  true

@listToTags = (tagsList) ->
  tags = {}
  for tag in tagsList
    tags[tag] = true
  tags

if Meteor.isServer
  Meteor.publish 'tags', (group) ->
    check group, String
    @autorun ->
      unless memberOfGroup group, findUser @userId
        return @ready()
      Tags.find
        group: group
        deleted: false

  Meteor.publish 'tags.all', (group) ->
    check group, String
    @autorun ->
      unless memberOfGroup group, findUser @userId
        return @ready()
      Tags.find
        group: group

Meteor.methods
  tagNew: (group, key, type) ->
    check Meteor.userId(), String  ## should be done by 'canPost'
    check group, String
    check key, String
    check type, "boolean"  ## only type supported for now
    unless canPost group, null
      throw new Meteor.Error 'tagNew.unauthorized',
        "Insufficient permissions to tag message in group '#{group}'"
    ## Forbid only-whitespace tag
    unless validTag key
      throw new Meteor.Error 'tagNew.invalid',
        "Invalid tag key '#{key}'"
    ## Only add if it doesn't exist already.
    old = Tags.findOne
      group: group
      key: key
    if old?
      if old.deleted
        Tags.update old._id,
          $set:
            deleted: false
            updator: Meteor.user().username
            updated: new Date
    else
      Tags.insert
        group: group
        key: key
        type: type
        deleted: false
        creator: Meteor.user().username
        created: new Date

  tagDelete: (group, key, maybe = false) ->
    check Meteor.userId(), String  ## should be done by 'canPost'
    check group, String
    check key, String
    check maybe, Boolean
    unless canPost group, null
      throw new Meteor.Error 'tagDelete.unauthorized',
        "Insufficient permissions to untag message in group '#{group}'"
    return if @isSimulation  ## can't check for global message existence
    any = Messages.findOne
      group: group
      "tags.#{escapeTag key}": $exists: true
    if any
      if maybe
        return
      else
        throw new Meteor.Error 'tagDelete.inUse',
          "Message #{any._id} still uses tag '#{key}'!"
    old = Tags.findOne
      group: group
      key: key
    if old? and not old.deleted
      Tags.update old._id,
        $set:
          deleted: true
          updator: Meteor.user().username
          updated: new Date
