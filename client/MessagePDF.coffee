import React, {useEffect, useRef, useState} from 'react'
import {useTracker} from 'meteor/react-meteor-data'
import {useInView} from 'react-intersection-observer'

import {ErrorBoundary} from './ErrorBoundary'
import {resolveTheme, oppositeTheme} from './theme'
import {useElementWidth} from './lib/resize'
import {TextTooltip} from './lib/tooltip'
import {themeDocument} from '/lib/settings'

#pdf2svg = false  # controls pdf.js rendering mode
pdfjs = null  # will become import of 'pdfjs-dist'

export messageTheme = new ReactiveDict

export getMessageTheme = (fileId) ->
  resolveTheme messageTheme.get(fileId) ? themeDocument()
export useMessageTheme = (fileId) ->
  useTracker ->
    getMessageTheme fileId
  , [fileId]

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
  [pageInput, setPageInput] = useState 1
  [pageNum, setPageNum] = useState()
  [numPages, setNumPages] = useState()
  [pageBack, setPageBack] = useState []
  [pageForward, setPageForward] = useState []
  [fit, setFit] = useState 'page'
  theme = useMessageTheme file
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
    fileData = findFile file
    unless fileData?
      return setProgress 0
    size = fileData.length
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
      .then (pageLoaded) => setPage pageLoaded
    else
      setPage undefined
    undefined
  , [pdf, pageNum]
  ## Compute page dimensions, and render page if it's in view
  elementWidth = useElementWidth ref
  useEffect ->
    return unless page? and elementWidth
    viewport = page.getViewport scale: 1
    ## Simulate width: 100%
    width = elementWidth
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
    Promise.all [renderTask.promise, page.getAnnotations()]
    .then ([rendered, annotationsLoaded]) ->
      replaceCanvas canvasRef, canvas
      setRendering false
      ## Clear existing annotations, and load this page's annotations
      setAnnotations []
      setAnnotationsTransform "scale(#{1/dpiScale},#{1/dpiScale}) matrix(#{scaledViewport.transform.join ','})"
      ## Annotation links, based loosely on
      ## https://stackoverflow.com/a/20141227/7797661
      setAnnotations(
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
    .catch (error) ->
      ## Ignore pdfjs's error when rendering gets canceled from page flipping
      throw error unless error.name == 'RenderingCancelledException'
    -> renderTask.cancel()
  , [page, elementWidth, fit, inView]

  ## Synchronize page input with navigation of page number
  useEffect =>
    setPageInput pageNum if pageNum?
  , [pageNum]

  clipPage = (newPage) =>
    newPage = 1 if newPage < 1
    newPage = numPages if newPage > numPages
    newPage
  onChangePage = (delta) => (e) =>
    e.currentTarget.blur()
    setPageNum clipPage pageNum + delta
  onInputPage = (e) =>
    setPageInput e.currentTarget.value
    p = Math.round e.currentTarget.valueAsNumber
    if 1 <= p <= numPages
      setPageNum p
  onPageBack = (e) =>
    setPageForward [pageNum, ...pageForward]
    setPageNum pageBack[0]
    setPageBack pageBack[1..]
  onPageForward = (e) =>
    setPageBack [pageNum, ...pageBack]
    setPageNum pageForward[0]
    setPageForward pageForward[1..]
  onFit = (newFit) => (e) =>
    e.currentTarget.blur()
    setFit newFit
  onTheme = (e) =>
    messageTheme.set file, oppositeTheme theme

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
          {if pageBack.length or pageForward.length
            <>
              <TextTooltip title="Back to page #{pageBack[0] ? ''}">
                <button className="btn btn-default" aria-label="Page back"
                 onClick={onPageBack} disabled={not pageBack.length}>
                  <span className="fas fa-arrow-left" aria-hidden="true"/>
                </button>
              </TextTooltip>
              <TextTooltip title="Forward to page #{pageForward[0] ? ''}">
                <button className="btn btn-default" aria-label="Page forward"
                 onClick={onPageForward} disabled={not pageForward.length}>
                  <span className="fas fa-arrow-right" aria-hidden="true"/>
                </button>
              </TextTooltip>
            </>
          }
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
          <TextTooltip title="Toggle dark mode via inversion">
            <button className="btn btn-default" aria-label="Toggle dark mode via inversion" onClick={onTheme}>
              <span className="fas #{if theme == 'dark' then 'fa-sun' else 'fa-moon'}" aria-hidden="true"/>
            </button>
          </TextTooltip>
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
          <span className="space form-inline">
            page
            <input className="form-control input-xs" type="number"
             value={pageInput} onChange={onInputPage} min="1" max={numPages}
             onBlur={(e) => setPageInput pageNum} />
            of {numPages}
          </span>
          {if rendering
            <i className="space">(rendering)</i>
          }
        </span>
      </>
    }
    <div className="pdf #{theme}" style={width: "#{dims.width}px", height: "#{dims.height}px"} ref={viewRef}>
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
            onClick = do (annotation) => (e) =>
              e.preventDefault()
              setPageBack [pageNum, ...pageBack]
              setPageForward []
              setPageNum annotation.explicitPage
          ### eslint-disable coffee/jsx-no-target-blank ###
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
          ### eslint-enable coffee/jsx-no-target-blank ###
        }
      </div>
    </div>
  </div>
WrappedMessagePDF.displayName = 'WrappedMessagePDF'
