@defaultAutopublish = true

@autopublish = ->
  Meteor.user().profile.autopublish ? defaultAutopublish

@defaultFormat = 'markdown'

@defaultTheme = 'light'
@theme = ->
  Meteor.user().profile.theme ? defaultTheme
