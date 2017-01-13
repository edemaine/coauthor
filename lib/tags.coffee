@Tags = new Mongo.Collection 'tags'

@sortTags = (tags) ->
  keys = (key for key of tags)
  keys.sort()
  for key in keys
    key: key
    value: tags[key]

## Currently, tags just map keys to "true".
## In the future, there will be other values, checked here.  (See #86.)
@validTags = (tags) ->
  for key, value of tags
    if value != true
      return false
  true

@listToTags = (tags) ->
  tags = {}
  for tag in tags
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
    Messages.update msg._id,
      $set: tags: tags
