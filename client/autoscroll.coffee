## Whenever route (page URL) changes, restore past scroll position after
## half a second, or top of page if we haven't been there before.
## Inspiration from https://github.com/iron-meteor/iron-router/issues/96 and
## https://github.com/sunstorymvp/meteor-iron-router-autoscroll

lastURL = null
pastTops = {}
loadedPastTops = false
transitioning = false

saveTops = _.debounce ->
  sessionStorage?.setItem? 'pastTops', JSON.stringify pastTops
, 100

$(window).scroll ->
  return if transitioning
  lastURL = document.URL
  pastTops[lastURL] = $(window).scrollTop()
  #console.log lastURL, $(window).scrollTop()
  saveTops()

Router.onBeforeAction ->
  transitioning = true
  if stored = sessionStorage?.getItem? 'pastTops'
    pastTops = JSON.parse stored
    #console.log 'loaded', pastTops
  @next()

Router.onAfterAction ->
  Meteor.setTimeout ->
    transitioning = false
    url = document.URL
    #console.log url, lastURL, pastTops[url] or 0
    return if url == lastURL
    lastURL = url
    top = pastTops[url] or 0  ## prevent from changing while page loads
    scroll = ->
      $('html, body').animate
        scrollTop: top
      , 200
    Tracker.autorun (computation) ->
      if Router.current().ready()
        scroll()
        computation.stop()
  , 100
