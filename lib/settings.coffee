@defaultAutopublish = true

@autopublish = (user = Meteor.user()) ->
  user?.profile?.autopublish ? defaultAutopublish

export defaultFormat = 'markdown'

@defaultTheme = 'light'
@theme = ->
  Meteor.user()?.profile?.theme ? defaultTheme

@defaultKeyboard = 'normal'

@userKeyboard = ->
  Meteor.user()?.profile?.keyboard ? defaultKeyboard

@timezoneCanon = (zone) -> zone.replace /[ (].*/, ''

if Meteor.isServer  ## only server has moment-timezone library
  @serverTimezone = ->
    ## Server/default timezone: Use settings's coauthor.timezone if specified.
    ## Otherwise, try Moment's guessing function.
    Meteor.settings?.coauthor?.timezone ? moment.tz.guess()

  console.log 'Server timezone:', serverTimezone()

  @momentInUserTimezone = (date, user = Meteor.user()) ->
    date = moment date unless date instanceof moment
    zone = user?.profile?.timezone
    zone = timezoneCanon zone if zone?
    unless zone and moment.tz.zone(zone)?
      ## Default timezone is the server's timezone
      zone = serverTimezone()
    date = date.tz zone if zone
    date
