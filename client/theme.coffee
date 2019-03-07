Meteor.startup ->
  lastTheme = 'light' ## initial value from link in layout.jade
  Tracker.autorun ->
    if themeGlobal() != lastTheme
      lastTheme = themeGlobal()
      $('#themeLink').remove()
      $('head').prepend """<link rel="stylesheet" href="/bootstrap/#{lastTheme}.min.css" id="themeLink"/>"""
