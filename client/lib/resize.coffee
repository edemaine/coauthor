import React, {useLayoutEffect, useState} from 'react'
import useResizeObserver from '@react-hook/resize-observer'

import {useDebounce} from './useDebounce'

export useElementWidth = (ref, debounce) ->
  [width, setWidth] = useState()
  useLayoutEffect getSize = ->
    setWidth ref.current.clientWidth
    undefined
  , [ref]
  useResizeObserver ref, (entry) ->
    setWidth entry.contentBoxSize?.inlineSize ? entry.contentRect.width
  #if debounce?
  #  width = 
  width
