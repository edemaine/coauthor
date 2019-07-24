Meteor.startup ->
  lastTheme = 'light' ## initial value from link in layout.jade
  $('body').addClass lastTheme
  Tracker.autorun ->
    if themeGlobal() != lastTheme
      $('body').removeClass lastTheme
      lastTheme = themeGlobal()
      $('body').addClass lastTheme
      $('#themeLink').remove()
      $('head').prepend """<link rel="stylesheet" href="/bootstrap/#{lastTheme}.min.css" id="themeLink"/>"""
