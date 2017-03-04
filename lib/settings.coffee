@defaultAutopublish = true

@autopublish = ->
  Meteor.user()?.profile?.autopublish ? defaultAutopublish

export defaultFormat = 'markdown'

@defaultTheme = 'light'
@theme = ->
  Meteor.user()?.profile?.theme ? defaultTheme

@userKeyboard = ->
  Meteor.user()?.profile?.keyboard ? defaultKeyboard
