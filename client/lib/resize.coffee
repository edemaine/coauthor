import {useLayoutEffect, useState} from 'react'
import useResizeObserver from '@react-hook/resize-observer'

export useElementWidth = (ref, debounce) ->
  [width, setWidth] = useState()
  useLayoutEffect ->
    setWidth ref.current.clientWidth
    undefined
  , [ref]
  useResizeObserver ref, (entry) ->
    setWidth entry.contentBoxSize?.inlineSize ? entry.contentRect.width
  width
