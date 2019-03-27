## Database of available emoji
@Emoji = new Mongo.Collection 'emoji'

## Database of emoji responses/messages
@EmojiMessages = new Mongo.Collection 'messages.emoji'

## Indexes
if Meteor.isServer
  ## This index makes it fast to find all undeleted emoji
  ## attached to a given message.
  EmojiMessages._ensureIndex [
    ['message', 1]
    ['deleted', 1]
  ]

## Always subscribe to group-global emoji
if Meteor.isServer
  Meteor.publish 'emoji.global', ->
    Emoji.find
      group: wildGroup
      deleted: $exists: false
else  ## client
  Meteor.subscribe 'emoji.global'

## Group-level emoji are available for all readable groups (including
## anonymous groups) and all groups of which you are a full or partial member.
## There's no actual way to add these emoji yet, though, so we don't yet
## subscribe to this publication anywhere.
if Meteor.isServer
  Meteor.publish 'emoji.group', (group) ->
    check group, String
    user = findUser @userId
    @autorun ->
      if memberOfGroupOrReadable group, user
        Emoji.find
          group: group
          deleted: $exists: false
      else
        @ready()

## Emoji message publications.  These aren't currently needed, thanks to the
## caching.
###
if Meteor.isServer
  Meteor.publish 'emoji.submessages', (msgId) ->
    check msgId, String
    root = message2root msgId
    @autorun ->
      if canSee root, false, findUser @userId
        EmojiMessages.find
          $or: [
            message: root
          , root: root
          ]
          deleted: false
      else
        @ready()

  Meteor.publish 'emoji.root', (group) ->
    check group, String
    user = findUser @userId
    @autorun ->
      if memberOfGroupOrReadable group, user
        EmojiMessages.find
          group: group
          root: null
          deleted: false
      else
        @ready()
###

## Emoji message methods
Meteor.methods
  emojiToggle: (msgId, symbol) ->
    ## Check permissions
    check msgId, String
    check symbol, String
    msg = findMessage msgId
    unless msg?
      throw new Meteor.Error 'messageEmojiToggle.invalidMessage',
        "No message with ID '#{msgId}'"
    group = msg.group
    unless canPost group, msg
      throw new Meteor.Error 'messageEmojiToggle.unauthorized',
        "Insufficient permissions to add emoji to message '#{msgId}' in group '#{group}'"

    ## Look up emoji
    emoji = Emoji.findOne
      symbol: symbol
      group: $in: [wildGroup, group]
    unless emoji?
      throw new Meteor.Error 'messageEmojiToggle.invalidEmoji',
        "No emoji with symbol '#{symbol}' in group '#{group}'"

    ## Toggle the state of this emoji
    return if @isSimulation  ## client does not have EmojiMessages
    creator = Meteor.user().username
    emojiMsg = EmojiMessages.findOne
      message: msgId
      symbol: symbol
      creator: creator
      deleted: false
    if emojiMsg?
      EmojiMessages.update emojiMsg._id,
        $set: deleted: new Date
      Messages.update msgId,
        $pull: "emoji.#{symbol}": creator
    else
      EmojiMessages.insert
        group: msg.group
        root: msg.root  ## null if this message is the root message
        message: msgId
        symbol: symbol
        creator: creator
        created: new Date
        deleted: false
      Messages.update msgId,
        $push: "emoji.#{symbol}": creator

  recomputeEmoji: ->
    ## Force recomputation of message `emoji` fields to match EmojiMessages
    ## database, in creation order.
    unless canSuper wildGroup
      throw new Meteor.Error 'recomputeEmoji.unauthorized',
        "Insufficient permissions to recompute emoji in group '#{wildGroup}'"
    return if @isSimulation  ## client doesn't have EmojiMessages
    Messages.find({}).forEach (msg) ->
      emoji = {}
      EmojiMessages.find
        message: msg._id
        deleted: false
      , sort: [['created', 'asc']]
      .forEach (emojiMsg) ->
        emoji[emojiMsg.symbol] ?= []
        emoji[emojiMsg.symbol].push emojiMsg.creator
      Messages.update msg._id,
        $set: emoji: emoji

## Emoji lookup tool.  Note that emojiFilter is modified by the function.
@emojiReplies = (message, emojiFilter = {}) ->
  message = findMessage message
  return [] unless message.emoji
  #for key, value of message.emoji
  #  if value.length == 0
  #    delete message.emoji[key]
  emojiFilter.symbol = $in: _.keys message.emoji
  emoji = Emoji.find emojiFilter
  .fetch()
  emojiMap = {}
  for emoj, i in emoji
    emoj.index = i
    emoj.who = message.emoji[emoj.symbol]
    emoj.count = emoj.who.length
    emojiMap[emoj.symbol] = emoj if emoj.count > 0
  symbols = _.keys emojiMap
  symbols = _.sortBy symbols, (emoj) -> emojiMap[emoj].index
  for symbol in symbols
    emojiMap[symbol]
  ### Without `emoji` attribute cache:
  msgs = EmojiMessages.find
    message: message._id ? message
    deleted: false
  .fetch()
  msgs = _.groupBy msgs, 'symbol'
  emojiFilter.symbol = $in: _.keys msgs
  emoji = Emoji.find emojiFilter
  .fetch()
  emojiMap = {}
  for emoj, i in emoji
    emoj.index = i
    emoj.who =
      for msg in _.sortBy msgs[emoj.symbol], 'created'
        msg.creator
    emoj.count = emoj.who.length
    emojiMap[emoj.symbol] = emoj
  symbols = _.keys emojiMap
  symbols = _.sortBy symbols, (emoj) -> emojiMap[emoj].index
  for symbol in symbols
    emojiMap[symbol]
  ###

## Default set of group-global emoji
if Meteor.isServer and Emoji.find().count() == 0

  Meteor.startup ->
    Emoji.insert
      symbol: 'thumbs-up'
      class: 'positive'
      description: '+1/agree'
      group: wildGroup
    Emoji.insert
      symbol: 'heart'
      class: 'neutral'
      description: 'heart'
      group: wildGroup
    Emoji.insert
      symbol: 'grin-beam'
      class: 'neutral'
      description: 'happy/funny'
      group: wildGroup
    Emoji.insert
      symbol: 'surprise'
      class: 'neutral'
      description: 'surprise'
      group: wildGroup
    Emoji.insert
      symbol: 'sad-tear'
      class: 'neutral'
      description: 'sad'
      group: wildGroup
    Emoji.insert
      symbol: 'check'
      class: 'neutral'
      description: 'checked'
      group: wildGroup
    Emoji.insert
      symbol: 'question'
      class: 'neutral'
      description: 'question/confusion'
      group: wildGroup
    Emoji.insert
      symbol: 'thumbs-down'
      class: 'negative'
      description: '-1/disagree'
      group: wildGroup
    #Emoji.insert
    #  symbol: 'birthday-cake'
    #  description: 'celebrate'
    #  group: wildGroup
