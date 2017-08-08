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

@timezoneCanon = (zone) -> zone.replace /[ (].*/, ''

if Meteor.isServer  ## only server has moment-timezone library
  @momentInUserTimezone = (date, user = Meteor.user()) ->
    date = moment date unless date instanceof moment
    zone = user?.profile?.timezone
    console.log user, zone
    zone = timezoneCanon zone if zone?
    ## Default timezone is the server's timezone
    zone = moment.tz.guess() unless zone
    date = date.tz zone if zone
    date
