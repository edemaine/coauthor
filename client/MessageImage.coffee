import React, {useEffect, useRef, useState} from 'react'
import {useTracker} from 'meteor/react-meteor-data'
import useEventListener from '@use-it/event-listener'

import {Orientation2rotate} from './lib/exif'
import {angle180} from '/lib/messages'

## Cache EXIF orientations, as files should be static
image2orientation = {}
export messageRotate = (message) ->
  if message.file not of image2orientation
    file = findFile message.file
    if file
      image2orientation[message.file] = file.metadata?.exif?.Orientation
  exifRotate = Orientation2rotate[image2orientation[message.file]]
  (message.rotate ? 0) + (exifRotate ? 0)

rotations = [
  angle: -90
  text: '90°'
  icon: 'fa-undo'
,
  angle: 180
  text: '180°'
  icon: 'fa-sync'
,
  angle: 90
  text: '90°'
  icon: 'fa-redo'
]
export MessageImage = React.memo ({message}) ->
  dropdownRef = useRef()
  refs =
    '-90': useRef()
    180: useRef()
    90: useRef()
  rotate = useTracker ->
    messageRotate message
  , [message]
  updates =
    for angle, ref of refs
      useImageTransform ref, rotate + parseInt angle
  ## Update rotated images when dropdown opens, because only then does parent
  ## have size so `scale` will be nonzero.
  useEffect ->
    $(dropdownRef.current).on 'shown.bs.dropdown', listener = (e) ->
      update() for update in updates
    -> $(dropdownRef.current).off 'shown.bs.dropdown', undefined, listener
  , [updates]

  onRotate = (e) ->
    angle = parseInt e.currentTarget.dataset.rotate
    Meteor.call 'messageUpdate', message._id,
      rotate: angle180 (message.rotate ? 0) + angle

  <div className="btn-group messageImage" ref={dropdownRef}>
    <button className="btn btn-info dropdown-toggle" type="button" data-toggle="dropdown" aria-haspopup="true" aria-expanded="false">
      {'Rotate '}
      <span className="caret"/>
    </button>
    <ul className="dropdown-menu dropdown-menu-right imageMenu" role="menu">
      {for {angle, text, icon} in rotations
        <li key={angle}>
          <a href="#" data-rotate={angle} onClick={onRotate}>
            <div>
              <img src={urlToFile message} ref={refs[angle]}/>
            </div>
            <span className="fas #{icon}"/>
            {' ' + text}
          </a>
        </li>
      }
    </ul>
  </div>
MessageImage.displayName = 'MessageImage'

useImageTransform = (imgRef, rotate) ->
  [windowWidth, setWindowWidth] = useState window.innerWidth
  useEventListener 'resize', (e) -> setWindowWidth window.innerWidth
  useEffect update = ->
    imageTransform imgRef.current, rotate if imgRef.current?
    undefined
  , [windowWidth, rotate]
  update

export imageTransform = (image, rotate) ->
  unless image.width
    return image.addEventListener 'load', (e) -> imageTransform image, rotate
  return unless image.parentNode?
  if rotate
    ## `rotate` is in clockwise degrees
    radians = -rotate * Math.PI / 180
    ## Computation based on https://stackoverflow.com/a/3231438
    width = Math.abs(Math.sin radians) * image.height + Math.abs(Math.cos radians) * image.width
    height = Math.abs(Math.sin radians) * image.width + Math.abs(Math.cos radians) * image.height
    #scale = image.width / width
    ## max-width: 100%
    scale = image.parentNode.getBoundingClientRect().width / width
    return unless scale  ## avoid zero scaling (invisible box)
    scale = 1 if scale > 1
    ## max-height: 100vh
    if height * scale > window.innerHeight
      scale *= window.innerHeight / (height * scale)
    width *= scale
    height *= scale
    image.style.transform = "translate(#{(width - image.width)/2}px, #{(height - image.height)/2}px) scale(#{scale}) rotate(#{rotate}deg)"
    image.parentNode.style.height = "#{height}px"
  else
    image.style.transform = null
    image.parentNode.style.height = null
