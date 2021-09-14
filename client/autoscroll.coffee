## Whenever route (page URL) changes, restore past scroll position after
## half a second, or top of page if we haven't been there before.
## Inspiration from https://github.com/iron-meteor/iron-router/issues/96 and
## https://github.com/sunstorymvp/meteor-iron-router-autoscroll
##
## Also support instantly going to certain paths (handled by WebApp)
## as specified by internalPath.

import {scrollToMessage} from './message.coffee'

lastURL = null
pastTops = {}
transitioning = 0
internalPath = /// ^ /(gridfs|file)/ ///
messagePath = /// ^ /([^/#])*/m/([^/#]*) $ ///

saveTops = _.debounce ->
  sessionStorage?.setItem? 'pastTops', JSON.stringify pastTops
, 100

$(window).scroll ->
  return if transitioning
  lastURL = document.URL
  pastTops[lastURL] = $(window).scrollTop()
  #console.log lastURL, $(window).scrollTop()
  saveTops()

## Match event handler spec from https://github.com/iron-meteor/iron-location/blob/c3ad6663c37d3a94f0929c78f3c3fef8adf84dc9/lib/location.js#L242
## so that we can override that handler via stopImmediatePropagation if needed.
$(document).on 'click', 'a[href]', (e) ->
  ## Only override left clicks
  return unless e.button == 0
  ## Only override vanilla clicks. Inspired by https://github.com/iron-meteor/iron-location/blob/c3ad6663c37d3a94f0929c78f3c3fef8adf84dc9/lib/location.js#L130
  return if e.metaKey or e.ctrlKey or e.shiftKey
  window.history.replaceState scrollTop: $(window).scrollTop(),
    'remember scroll'
  ## If we click on a link with a hash mark in it, forget and therefore
  ## don't scroll to remembered position.
  if e.currentTarget?.href?.endsWith? '#'
    delete pastTops[e.currentTarget.href[...e.currentTarget.href.length-1]]
  else if e.currentTarget?.hash
    delete pastTops[e.currentTarget.href]
    ## If we click on a hash link to the same message again, scroll there.
    #if e.currentTarget.href == window.location.toString()
    ## More generally, if we click on a hash link within the current page,
    ## scroll there smoothly.
    if e.currentTarget.host == window.location.host and
       e.currentTarget.pathname == window.location.pathname
      scrollToMessage e.currentTarget.hash
  ## Instantly go to internal paths, bypassing Iron Router
  if e.currentTarget?.host == window.location.host and
     internalPath.test e.currentTarget?.pathname
    e.preventDefault()
    e.stopImmediatePropagation?()
    window.location = e.currentTarget.href
  ## If we follow a link to a message within the current thread/subthread,
  ## treat the link like a hash link instead.
  if e.currentTarget?.host == window.location.host and
     not e.currentTarget.hash and
     not e.currentTarget.href.endsWith('#') and  # used by lots of buttons
     not e.currentTarget.classList.contains('btn') and
     (targetMatch = messagePath.exec e.currentTarget.pathname)? and
     (hereMatch = messagePath.exec window.location.pathname)? and
     (targetMatch[1] in [hereMatch[1], '*']) # matching group names
    hereMsg = Messages.findOne hereMatch[2]
    targetMsg = Messages.findOne targetMatch[2]
    if hereMsg? and targetMsg? and
       (hereMsg.root ? hereMsg._id) == (targetMsg.root ? targetMsg._id)
      ancestor = targetMsg
      while ancestor? and ancestor._id != hereMsg._id
        ancestor = findMessageParent ancestor
      if ancestor?
        e.preventDefault()
        e.stopImmediatePropagation?()
        window.history.pushState null, 'scroll to message',
          "#{window.location.pathname}##{targetMsg._id}"
        scrollToMessage targetMsg._id

## Handle browser back/forward button within the same page
## (which doesn't trigger a Router action).
window.addEventListener 'popstate', (e) ->
  ## Wait a tick to go after browser does its own scrolling for the hash
  transitioning += 1
  Meteor.defer ->
    transitioning -= 1
    if e.state?.scrollTop?
      $('html, body').scrollTop e.state.scrollTop
    else if document.URL of pastTops
      $('html, body').scrollTop pastTops[document.URL] or 0
    else
      ## No known view for this URL; scroll to the given hash
      scrollToMessage window.location.hash if window.location.hash.length > 1

Router.onBeforeAction ->
  transitioning += 1
  if _.isEmpty(pastTops) and stored = sessionStorage?.getItem? 'pastTops'
    pastTops = JSON.parse stored
    #console.log 'loaded', pastTops
  @next()

Router.onAfterAction ->
  Meteor.defer ->
    transitioning -= 1
    url = document.URL
    #console.log url, lastURL, pastTops[url] or 0
    return if url == lastURL
    lastURL = url
    top = pastTops[url] or 0  ## prevent from changing while page loads
    scroll = ->
      $('html, body').scrollTop top
      #$('html, body').animate
      #  scrollTop: top
      #, 200
    if top > 0
      Tracker.autorun (computation) ->
        if Router.current().ready()
          scroll()
          computation.stop()
    else
      scroll()
