import React, {useEffect, useRef, useState} from 'react'
import {useTracker} from 'meteor/react-meteor-data'
import useEventListener from '@use-it/event-listener'
import {useInView} from 'react-intersection-observer'

import {ErrorBoundary} from './ErrorBoundary'
import {TextTooltip} from './lib/tooltip'

#pdf2svg = false  # controls pdf.js rendering mode
pdfjs = null  # will become import of 'pdfjs-dist'

export MessagePDF = ({file}) ->
  <ErrorBoundary>
    <WrappedMessagePDF file={file}/>
  </ErrorBoundary>
MessagePDF.displayName = 'MessagePDF'

replaceCanvas = (ref, canvas) ->
  ref.current.replaceWith canvas
  ref.current = canvas
nullCanvas = ->
  canvas = document.createElement 'canvas'
  canvas.width = canvas.height = 0
  canvas

WrappedMessagePDF = React.memo ({file}) ->
  ref = useRef()
  [viewRef, inView] = useInView
    rootMargin: '100%'  # within one screenful is "in view"
  canvasRef = useRef()
  [progress, setProgress] = useState 0
  [rendering, setRendering] = useState false
  [pageNum, setPageNum] = useState()
  [numPages, setNumPages] = useState()
  [fit, setFit] = useState 'page'
  [dims, setDims] = useState {width: 0, height: 0}
  [pdf, setPdf] = useState()
  [page, setPage] = useState()
  [annotations, setAnnotations] = useState []
  [annotationsTransform, setAnnotationsTransform] = useState()

  useTracker ->
    ## Reset
    setPdf null
    setProgress 0
    setDims {width: 0, height: 0}
    replaceCanvas canvasRef, nullCanvas() if canvasRef.current?.width
    ## Load pdfjs
    unless pdfjs?
      Session.set 'pdfjsLoading', true
      Session.get 'pdfjsLoading'  # rerun tracker once pdfjs loaded
      return import('pdfjs-dist').then (imported) ->
        pdfjs = imported
        pdfjs.GlobalWorkerOptions.workerSrc = '/pdf.worker.min.js'  # in /public
        Session.set 'pdfjsLoading', false
    ## Load PDF file
    size = findFile(file).length
    loader = pdfjs.getDocument urlToInternalFile file
    loader.onProgress = (data) ->
      setProgress Math.round 100 * data.loaded / size
    loader.promise.then (pdfLoaded) ->
      setProgress null
      setPageNum 1
      setNumPages pdfLoaded.numPages
      setPdf pdfLoaded
  , [file]
  ## Load page of PDF as page number changes
  useEffect ->
    if pdf? and pageNum?
      pdf.getPage pageNum
      .then (pageLoaded) -> setPage pageLoaded
    else
      setPage undefined
    undefined
  , [pdf, pageNum]
  ## Compute page dimensions, and render page if it's in view
  [windowWidth, setWindowWidth] = useState window.innerWidth
  useEventListener 'resize', (e) -> setWindowWidth window.innerWidth
  useEffect ->
    return unless page?
    viewport = page.getViewport scale: 1
    ## Simulate width: 100%
    width = ref.current.clientWidth
    height = width * viewport.height / viewport.width
    ## Simulate max-height: 100vh
    if fit == 'page'
      if height > window.innerHeight
        height = window.innerHeight
        width = height * viewport.width / viewport.height
    setDims {width, height} unless dims.width == width and dims.height == height
    ## If out of view, destroy any rendering
    unless inView
      replaceCanvas canvasRef, nullCanvas() if canvasRef.current.width
      return
    ## Secondary canvas for double-buffered rendering
    canvas = document.createElement 'canvas'
    context = canvas.getContext '2d'
    ## Based on https://www.html5rocks.com/en/tutorials/canvas/hidpi/
    dpiScale = (window.devicePixelRatio or 1) /
      (context.webkitBackingStorePixelRatio or
       context.mozBackingStorePixelRatio or
       context.msBackingStorePixelRatio or
       context.oBackingStorePixelRatio or
       context.backingStorePixelRatio or 1)
    canvas.width = width * dpiScale
    canvas.height = height * dpiScale
    #unless dpiScale == 1
    canvas.style.transform = "scale(#{1/dpiScale},#{1/dpiScale})"
    canvas.style.transformOrigin = "0% 0%"
    scaledViewport = page.getViewport scale: dpiScale * width / viewport.width
    setRendering true
    renderTask = page.render
      canvasContext: context
      viewport: scaledViewport
    renderTask.promise.then ->
      replaceCanvas canvasRef, canvas
      setRendering false
      ## Clear existing annotations, and load this page's annotations
      setAnnotations []
      setAnnotationsTransform "scale(#{1/dpiScale},#{1/dpiScale}) matrix(#{scaledViewport.transform.join ','})"
      ## Annotation links, based loosely on
      ## https://stackoverflow.com/a/20141227/7797661
      page.getAnnotations().then (annotationsLoaded) -> setAnnotations(
        for annotation in annotationsLoaded
          if annotation.dest  # local link
            ## Refer to https://github.com/mozilla/pdf.js/blob/master/web/pdf_link_service.js goToDestination & _goToDestinationHelper
            annotation.explicit = await pdf.getDestination annotation.dest
            unless Array.isArray annotation.explicit
              console.warn "Invalid link destination #{annotation.dest} -> #{annotation.explicit}"
              continue
            if Number.isInteger annotation.explicit[0]
              annotation.explicitPage = 1 + annotation.explicit[0]
            else
              annotation.explicitPage = 1 + await pdf.getPageIndex annotation.explicit[0]
          annotation
      )
    -> renderTask.cancel()
  , [page, windowWidth, fit, inView]

  onChangePage = (delta) -> (e) ->
    e.currentTarget.blur()
    newPage = pageNum + delta
    newPage = 1 if newPage < 1
    newPage = numPages if newPage > numPages
    setPageNum newPage
  onFit = (newFit) -> (e) ->
    e.currentTarget.blur()
    setFit newFit

  <div ref={ref}>
    {if progress?
      <div className="progress">
        <div className="progress-bar" role="progressbar" aria-valuemin="0" aria-valuenow={progress} aria-valuemax="100" style={width: "#{progress}%"; minWidth: "2em"}>
          {progress}%
        </div>
      </div>
    else
      <>
        <div className="btn-group btn-group-xs pdfButtons">
          {if fit == 'page'
            <TextTooltip title="Fit to width">
              <button className="btn btn-default fitWidth" aria-label="Fit width" onClick={onFit 'width'}>
                <span className="fas fa-expand-arrows-alt" aria-hidden="true"/>
              </button>
            </TextTooltip>
          else
            <TextTooltip title="Fit full page to screen">
              <button className="btn btn-default fitPage" aria-label="Fit page" onClick={onFit 'page'}>
                <span className="fas fa-compress-arrows-alt" aria-hidden="true"/>
              </button>
            </TextTooltip>
          }
          <TextTooltip title="Previous page">
            <button className="btn btn-default prevPage #{if pageNum <= 1 then 'disabled'}" aria-label="Previous page" onClick={onChangePage -1}>
              <span className="fas fa-backward" aria-hidden="true"/>
            </button>
          </TextTooltip>
          <TextTooltip title="Next page">
            <button className="btn btn-default nextPage #{if pageNum >= numPages then 'disabled'}" aria-label="Next page" onClick={onChangePage +1}>
              <span className="fas fa-forward" aria-hidden="true"/>
            </button>
          </TextTooltip>
        </div>
        <span className="pdfStatus">
          <span className="space">
            page {pageNum} of {numPages}
          </span>
          {if rendering
            <i className="space">(rendering)</i>
          }
        </span>
      </>
    }
    <div className="pdf" style={width: "#{dims.width}px", height: "#{dims.height}px"} ref={viewRef}>
      <canvas width="0" height="0" ref={canvasRef}/>
      <div className="annotations" style={
        transform: annotationsTransform
        transformOrigin: "0% 0%"
      }>
        {for annotation in annotations
          continue unless annotation.subtype == 'Link'
          continue unless annotation.rect
          continue unless annotation.url or annotation.dest
          if annotation.url  # open URL links in new tab
            try
              title = (new URL annotation.url).host
            catch
              title = annotation.url
            title = "Open #{title} in new tab"
            onClick = undefined
          else if annotation.dest  # local link
            ## Refer to https://github.com/mozilla/pdf.js/blob/master/web/pdf_link_service.js goToDestination & _goToDestinationHelper
            title = "Page #{annotation.explicitPage}"
            ## x,y coordinates given by explicit[1..4]: https://github.com/mozilla/pdf.js/blob/master/web/base_viewer.js scrollPageIntoView
            onClick = do (annotation) -> (e) ->
              e.preventDefault()
              setPageNum annotation.explicitPage
          ### eslint-disable react/jsx-no-target-blank ###
          <TextTooltip key={annotation.id} title={title}>
            <a style={
              left: "#{annotation.rect[0]}px"
              top: "#{annotation.rect[1]}px"
              width: "#{annotation.rect[2] - annotation.rect[0]}px"
              height: "#{annotation.rect[3] - annotation.rect[1]}px"
            } href={annotation.url or '#'}
            target={if annotation.url then '_blank'}
            rel={if annotation.url then 'noreferrer'}
            onClick={onClick}/>
          </TextTooltip>
          ### eslint-enable react/jsx-no-target-blank ###
        }
      </div>
    </div>
  </div>
WrappedMessagePDF.displayName = 'WrappedMessagePDF'
