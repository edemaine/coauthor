prefersDark = window.matchMedia '(prefers-color-scheme: dark)'

export resolveTheme = (theme) ->
  if theme == 'auto'
    if prefersDark.matches
      'dark'
    else
      'light'
  else
    theme

lastTheme = null  ## initial value from link in layout.jade

## This used to be wrapped in Meteor.startup, but it seems unnecessary as
## <head> is always loaded, and we want theme to load ASAP.
Tracker.autorun updateTheme = ->
  newTheme = resolveTheme themeGlobal()
  if newTheme != lastTheme
    $('body').removeClass lastTheme
    $('body').addClass newTheme
    $('#themeLink').remove()
    $('head').prepend """<link rel="stylesheet" href="/bootstrap/#{newTheme}.min.css" id="themeLink"/>"""
    lastTheme = newTheme

## To implement 'auto' theme, listen to changes to browser's preference.
## Safari requires `addListener` instead of `addEventListener 'change'`.
prefersDark.addListener? updateTheme
