@defaultAutopublish = true

@autopublish = ->
  Meteor.user()?.profile?.autopublish ? defaultAutopublish

export defaultFormat = 'markdown'

@defaultTheme = 'light'
@theme = ->
  Meteor.user()?.profile?.theme ? defaultTheme

@defaultKeyboard = 'normal'

@userKeyboard = ->
  Meteor.user()?.profile?.keyboard ? defaultKeyboard
