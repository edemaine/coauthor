export defaultAutopublish = true

export autopublish = (user = Meteor.user()) ->
  user?.profile?.autopublish ? defaultAutopublish

export defaultFormat = 'markdown'

export defaultThemeEditor = 'auto'
export defaultThemeGlobal = 'auto'
export defaultThemeDocument = 'auto'
export themeEditor = ->
  Session?.get('coop:themeEditor') ? \
  Meteor.user()?.profile?.theme?.editor ? defaultThemeEditor
export themeGlobal = ->
  Session?.get('coop:themeGlobal') ? \
  Meteor.user()?.profile?.theme?.global ? defaultThemeGlobal
export themeDocument = ->
  Session?.get('coop:themeDocument') ? \
  Meteor.user()?.profile?.theme?.document ? defaultThemeDocument

export defaultKeyboard = 'normal'

export userKeyboard = ->
  Meteor.user()?.profile?.keyboard ? defaultKeyboard

export timezoneCanon = (zone) -> zone.replace /[ (].*/, ''
