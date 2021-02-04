@Tags = new Mongo.Collection 'tags'

if Meteor.isServer
  Tags._ensureIndex [['group', 1], ['deleted', 1]]

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
    unless validTag(key)
      return false
  true

@listToTags = (tagsList) ->
  tags = {}
  for tag in tagsList
    tags[tag] = true
  tags

## Transition tags format from old array to object mapping
if Meteor.isServer
  Messages.find
    $where: "return Array.isArray(this.tags)"
  .forEach (msg) ->
    tags = listToTags msg.tags
    #console.log msg._id, tags
    Messages.update msg._id,
      $set: tags: tags
  MessagesDiff.find
    $where: "return Array.isArray(this.tags)"
  .forEach (msg) ->
    tags = listToTags msg.tags
    #console.log msg._id, tags
    MessagesDiff.update msg._id,
      $set: tags: tags

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

## Find used but missing tags (for inheriting old databases).
if Meteor.isServer
  Messages.find
    deleted: false
  .forEach (message) ->
    return unless message.tags
    seeking = _.keys message.tags
    missing = listToTags seeking
    tags = Tags.find
      group: message.group
      key: $in: seeking
    .forEach (tag) ->
      delete missing[tag.key]
    for tag of missing
      console.log 'Adding missing tag', tag, 'in group', message.group
      Tags.insert
        group: message.group
        key: tag
        type: 'boolean'
        deleted: false
        created: new Date
