@defaultAutopublish = true

@autopublish = ->
  Meteor.user().profile.autopublish ? defaultAutopublish

@defaultFormat = 'markdown'
