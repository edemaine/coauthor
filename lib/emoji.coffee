@Emoji = new Mongo.Collection 'emoji'

if Meteor.isServer
  Meteor.publish 'emoji.global', ->
    Emoji.find
      group: wildGroup
else  ## client
  Meteor.subscribe 'emoji.global'

if Meteor.isServer and Emoji.find().count() == 0
  Emoji.insert
    symbol: 'thumbs-up'
    description: '+1/agree'
    group: wildGroup
  Emoji.insert
    symbol: 'thumbs-down'
    description: '-1/disagree'
    group: wildGroup
  Emoji.insert
    symbol: 'question'
    description: 'question/confusion'
    group: wildGroup
  Emoji.insert
    symbol: 'check'
    description: 'checked'
    group: wildGroup
  Emoji.insert
    symbol: 'heart'
    description: 'love'
    group: wildGroup
  Emoji.insert
    symbol: 'birthday-cake'
    description: 'celebrate'
    group: wildGroup
  Emoji.insert
    symbol: 'laugh-beam'
    description: 'laugh'
    group: wildGroup
