## Whenever route (page URL) changes, restore past scroll position after
## half a second, or top of page if we haven't been there before.
## Inspiration from https://github.com/iron-meteor/iron-router/issues/96 and
## https://github.com/sunstorymvp/meteor-iron-router-autoscroll

lastURL = null
pastTops = {}
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

$(window).click (e) ->
  ## If we click on a link with a hash mark in it, forget and therefore
  ## don't scroll to remembered position.
  if e.target?.href?.endsWith? '#'
    delete pastTops[e.target.href[...e.target.href.length-1]]
  else if e.target?.hash
    delete pastTops[e.target.href]
    ## If we click on a hash link to the same message again, scroll there.
    #if e.target.href == window.location.toString()
    ## More generally, if we click on a hash link within the current page,
    ## scroll there smoothly.
    if e.target.hostname == window.location.hostname and
       e.target.pathname == window.location.pathname
      scrollToMessage e.target.hash

Router.onBeforeAction ->
  transitioning = true
  if _.isEmpty(pastTops) and stored = sessionStorage?.getItem? 'pastTops'
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
