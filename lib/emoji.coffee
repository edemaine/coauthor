## Database of available emoji
@Emoji = new Mongo.Collection 'emoji'

## Database of emoji responses/messages
@EmojiMessages = new Mongo.Collection 'messages.emoji'

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

## Emoji message publications
if Meteor.isServer
  Meteor.publish 'emoji.submessages', (msgId) ->
    check msgId, String
    root = message2root msgId
    @autorun ->
      if canSee root, false, findUser @userId
        EmojiMessages.find
          root: root
          deleted: false
      else
        @ready()

  Meteor.publish 'emoji.root', (group) ->
    check group, String
    @autorun ->
      if memberOfGroupOrReadable group, user
        EmojiMessages.find
          group: group
          deleted: false
      else
        @ready()

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
    creator = Meteor.user().username
    emojiMsg = EmojiMessages.findOne
      message: msgId
      creator: creator
      deleted: false
    if emojiMsg?
      EmojiMessages.update emojiMsg._id,
        $set: deleted: new Date
    else
      EmojiMessages.insert
        group: msg.group
        root: message2root msg
        message: msgId
        symbol: symbol
        creator: creator
        created: new Date
        deleted: false

## Default set of group-global emoji
if Meteor.isServer and Emoji.find().count() == 0
  Meteor.startup ->
    Emoji.insert
      symbol: 'thumbs-up'
      class: 'positive'
      description: '+1/agree'
      group: wildGroup
    Emoji.insert
      symbol: 'thumbs-down'
      class: 'negative'
      description: '-1/disagree'
      group: wildGroup
    Emoji.insert
      symbol: 'heart'
      class: 'positive'
      description: 'love'
      group: wildGroup
    Emoji.insert
      symbol: 'check'
      class: 'positive'
      description: 'checked'
      group: wildGroup
    Emoji.insert
      symbol: 'question'
      class: 'negative'
      description: 'question/confusion'
      group: wildGroup
    #Emoji.insert
    #  symbol: 'birthday-cake'
    #  description: 'celebrate'
    #  group: wildGroup
    #Emoji.insert
    #  symbol: 'laugh-beam'
    #  description: 'laugh'
    #  group: wildGroup
