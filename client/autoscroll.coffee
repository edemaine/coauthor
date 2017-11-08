## Whenever route (page URL) changes, restore past scroll position after
## half a second, or top of page if we haven't been there before.
## Inspiration from https://github.com/iron-meteor/iron-router/issues/96 and
## https://github.com/sunstorymvp/meteor-iron-router-autoscroll

lastURL = null
pastTops = {}
transitioning = false

$(window).scroll ->
  return if transitioning
  lastURL = document.URL
  pastTops[lastURL] = $(window).scrollTop()
  #console.log lastURL, $(window).scrollTop()

Router.onBeforeAction ->
  transitioning = true
  @next()

Router.onAfterAction ->
  Meteor.setTimeout ->
    transitioning = false
    url = document.URL
    #console.log url, lastURL, pastTops[url] or 0
    return if url == lastURL
    lastURL = url
    $('html, body').animate
      scrollTop: pastTops[url] or 0
    , 200
  , 100
