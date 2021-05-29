import {useLayoutEffect, useState} from 'react'
import useResizeObserver from '@react-hook/resize-observer'

export useElementWidth = (ref) ->
  [width, setWidth] = useState()
  useLayoutEffect ->
    setWidth ref.current.clientWidth if ref.current?
    undefined
  , [ref]
  useResizeObserver ref, (entry) ->
    setWidth entry.contentBoxSize?.inlineSize ? entry.contentRect.width
  width
