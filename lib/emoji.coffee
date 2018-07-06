@Emoji = new Mongo.Collection 'emoji'

if Meteor.isServer
  Meteor.publish 'emoji.global', ->
    Emoji.find
      group: wildGroup
else  ## client
  Meteor.subscribe 'emoji.global'

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
