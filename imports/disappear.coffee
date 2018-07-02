## This code is based in part on the appear.js library
## [https://github.com/creativelive/appear/], written by creativeLIVE, Inc.
## in 2004, and distributed under the MIT License.
##
## This code is written from scratch in CoffeeScript
## and with a completely different API designed for `client/messagePDF.coffee`.

## appear's `viewable` function adapted from
## https://raw.githubusercontent.com/creativelive/appear/master/dist/appear.js
visible = (node) ->
  rect = node.getBoundingClientRect()
  windowHeight = window.innerHeight || document.documentElement.clientHeight
  windowWidth = window.innerWidth || document.documentElement.clientWidth
  (rect.top + rect.height) >= -windowHeight and
  (rect.left + rect.width) >= -windowWidth and
  (rect.bottom - rect.height) <= 2 * windowHeight and
  (rect.right - rect.width) <= 2 * windowWidth
  ## `2 *` and `-` means view anything within one screenful of visible

tracking = []

disappearCheckOne = (track) ->
  now = visible track.node
  if track.visible != now  ## change of state
    if track.visible == true
      ## Call disappear() when previously visible and now invisible
      track.disappear()
    else if now
      ## Call appear() when now visible and previously invisible or undefined
      track.appear()
    track.visible = now

## Force a check of all tracked elements.
export disappearCheck = _.debounce ->
  for track in tracking
    disappearCheckOne track
, 50

## Called automatically when needed by `disappearTrack`
disappearEnable = ->
  window.addEventListener 'resize', disappearCheck, false
  window.addEventListener 'scroll', disappearCheck, false

## Called automatically when needed by `disappearUntrack`
disappearDisable = ->
  window.removeEventListener 'resize', disappearCheck, false
  window.removeEventListener 'scroll', disappearCheck, false

## Start tracking the given object, of the form:
##   node: <DOM element>
##   appear: -> ...callback when it is visible...
##   disappear: -> ...callback when it is invisible...
export disappearTrack = (track) ->
  disappearCheckOne track
  tracking.push track
  if tracking.length == 1
    disappearEnable()

## Stop tracking the given DOM node (`node` field given to `disappearTrack`).
export disappearUntrack = (node) ->
  tracking = (track for track in tracking when track.node != node)
  if tracking.length == 0
    disappearDisable()
