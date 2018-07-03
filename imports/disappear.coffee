## This code is based in part on the appear.js library
## [https://github.com/creativelive/appear/], written by creativeLIVE, Inc.
## in 2004, and distributed under the MIT License.
##
## This code is written from scratch in CoffeeScript
## and with a completely different API designed for `client/messagePDF.coffee`.

## appear's `viewable` function adapted from
## https://raw.githubusercontent.com/creativelive/appear/master/dist/appear.js
export visible = (node) ->
  rect = node.getBoundingClientRect()
  windowHeight = window.innerHeight || document.documentElement.clientHeight
  windowWidth = window.innerWidth || document.documentElement.clientWidth
  (rect.top + rect.height) >= -windowHeight and
  (rect.left + rect.width) >= -windowWidth and
  (rect.bottom - rect.height) <= 2 * windowHeight and
  (rect.right - rect.width) <= 2 * windowWidth
  ## `2 *` and `-` means view anything within one screenful of visible

tracking = []

checkOne = (tracked) ->
  now = visible tracked.node
  old = tracked.visible
  if old != now  ## change of state
    tracked.visible = now  ## update status before calling (dis)appear()
    if old == true
      ## Call disappear() when previously visible and now invisible
      tracked.disappear()
    else if now
      ## Call appear() when now visible and previously invisible or undefined
      tracked.appear()

## Force a check of all tracked elements.
export check = _.debounce ->
  for tracked in tracking
    checkOne tracked
, 50

## Called automatically when needed by `track`
enable = ->
  window.addEventListener 'resize', check, false
  window.addEventListener 'scroll', check, false

## Called automatically when needed by `untrack`
disable = ->
  window.removeEventListener 'resize', check, false
  window.removeEventListener 'scroll', check, false

## Start tracking the given object, of the form:
##   node: <DOM element>
##   appear: -> ...callback when it is visible...
##   disappear: -> ...callback when it is invisible...
## The object will be modified to have a `visible` field set to true or false
## as its visibility changes.
export track = (tracked) ->
  #checkOne tracked
  tracking.push tracked
  if tracking.length == 1
    enable()
  check()

## Stop tracking the given DOM node (`node` field given to `track`).
export untrack = (node) ->
  tracking = (tracked for tracked in tracking when tracked.node != node)
  if tracking.length == 0
    disable()
