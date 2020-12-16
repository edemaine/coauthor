pdf2svg = false  ## controls pdf.js rendering mode

Template.messagePDF.onCreated ->
  @page = new ReactiveVar 1
  @pages = new ReactiveVar 1
  @progress = new ReactiveVar null
  @rendering = new ReactiveVar false
  @fit = new ReactiveVar 'page'

Template.messagePDF.onDestroyed ->
  window.removeEventListener 'resize', @onResize if @onResize?
  `import('/imports/disappear')`.then (disappear) =>
    disappear.untrack @container

Template.messagePDF.onRendered ->
  @autorun =>
    @progress.get()
    @fit.get()
    tooltipUpdate()
  @container = @find 'div.pdf'
  window.addEventListener 'resize', @onResize = _.debounce (=> @resize?()), 100
  `import('pdfjs-dist')`.then (pdfjs) =>
    pdfjs.GlobalWorkerOptions.workerSrc = '/pdf.worker.min.js'  ## in /public
    @autorun =>
      file = Template.currentData()
      size = findFile(file).length
      @progress.set 0
      loader = pdfjs.getDocument urlToInternalFile file
      loader.onProgress = (data) =>
        @progress.set Math.round 100 * data.loaded / size
      loader.promise.then (pdf) =>
        @progress.set null
        @pages.set pdf.numPages
        @track =
          node: @container
          appear: => @resize() #; console.log 'hi', msg.file
          disappear: => @container.innerHTML = '' #; console.log 'bye', msg.file
        @renderPage = =>
          annotationsDiv = document.createElement 'div'
          annotationsDiv.className = 'annotations'
          pdf.getPage(@page.get()).then (page) =>
            viewport = page.getViewport scale: 1
            @resize = =>
              ## Simulate width: 100%
              width = @container.parentElement.clientWidth
              height = width * viewport.height / viewport.width
              ## Simulate max-height: 100vh
              if @fit.get() == 'page'
                if height > window.innerHeight
                  height = window.innerHeight
                  width = height * viewport.width / viewport.height
              @container.style.width = "#{width}px"
              @container.style.height = "#{height}px"
              return unless @track?.visible
              unless pdf2svg
                #canvas = @find 'canvas.pdf'
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
                annotationsDiv.style.transform = "scale(#{1/dpiScale},#{1/dpiScale}) matrix(#{scaledViewport.transform.join ','})"
                annotationsDiv.style.transformOrigin = "0% 0%"
                ## Cancel any ongoing page render, then render the page.
                @renderTask.cancel() if @renderTask?
                @rendering.set true
                @renderTask = page.render
                  canvasContext: context
                  viewport: scaledViewport
                renderTask = @renderTask
                @renderTask.promise.then (=>
                  ## Replace existing canvas with this one, if still fresh.
                  if renderTask == @renderTask
                    @container.innerHTML = ''
                    @container.appendChild canvas
                    @container.appendChild annotationsDiv
                  ## Mark renderTask done (no longer needs to be canceled).
                  @renderTask = null
                  @rendering.set false
                ), (error) =>  ## ignore render cancellation (which we cause)
                  unless error instanceof pdfjs.RenderingCancelledException
                    throw error
            @resize()
            if @track.visible == undefined
              `import('/imports/disappear')`.then (disappear) =>
                if @track.visible == undefined
                  disappear.track @track
            if pdf2svg
              page.getOperatorList().then (opList) ->
                svgGfx = new pdfjs.SVGGraphics page.commonObjs, page.objs
                svgGfx.getSVG opList, viewport
                .then (svg) ->
                  #svg.preserveAspectRatio = true
                  @container.innerHTML = ''
                  @container.appendChild svg
            ## Annotation links, based loosely on
            ## https://stackoverflow.com/a/20141227/7797661
            page.getAnnotations().then (annotations) =>
              for annotation in annotations
                return unless annotation.subtype == 'Link'
                return unless annotation.rect
                return unless annotation.url or annotation.dest
                anchor = document.createElement 'a'
                anchor.style.left = "#{annotation.rect[0]}px"
                anchor.style.top = "#{annotation.rect[1]}px"
                anchor.style.width = "#{annotation.rect[2] - annotation.rect[0]}px"
                anchor.style.height = "#{annotation.rect[3] - annotation.rect[1]}px"
                anchor.href = annotation.url or '#'
                if annotation.url  # open URL links in new tab
                  anchor.target = '_blank'
                  anchor.rel = 'noopener noreferrer'
                else if annotation.dest  # local link
                  ## Refer to https://github.com/mozilla/pdf.js/blob/master/web/pdf_link_service.js goToDestination & _goToDestinationHelper
                  do (dest = annotation.dest) =>
                    anchor.addEventListener 'click', (e) =>
                      e.preventDefault()
                      pdf.getDestination dest
                      .then (explicit) =>
                        unless Array.isArray explicit
                          return console.error "Invalid link destination #{dest} -> #{explicit}"
                        if Number.isInteger explicit[0]
                          @page.set explicit[0] + 1
                          @renderPage?()
                        else
                          pdf.getPageIndex explicit[0]
                          .then (pageNum) =>
                            @page.set pageNum + 1
                            @renderPage?()
                            ## x,y coordinates given by explicit[1..4]: https://github.com/mozilla/pdf.js/blob/master/web/base_viewer.js scrollPageIntoView
                annotationsDiv.appendChild anchor
        @renderPage()

Template.messagePDF.helpers
  progress: -> Template.instance().progress.get()
  multiplePages: -> Template.instance().pages.get() > 1
  page: -> Template.instance().page.get()
  pages: -> Template.instance().pages.get()
  rendering: -> Template.instance().rendering.get()
  disablePrev: ->
    if Template.instance().page.get() <= 1
      'disabled'
  disableNext: ->
    if Template.instance().page.get() >= Template.instance().pages.get()
      'disabled'
  fitPage: ->
    Template.instance().fit.get() == 'page'

Template.messagePDF.events
  'click .prevPage': (e, t) ->
    e.currentTarget.blur()
    if t.page.get() > 1
      t.page.set t.page.get() - 1
      t.renderPage?()
  'click .nextPage': (e, t) ->
    e.currentTarget.blur()
    if t.page.get() < t.pages.get()
      t.page.set t.page.get() + 1
      t.renderPage?()
  'click .fitWidth': (e, t) ->
    e.currentTarget.blur()
    tooltipHide t  ## because button disappears from DOM
    t.fit.set 'width'
    t.renderPage?()
  'click .fitPage': (e, t) ->
    e.currentTarget.blur()
    tooltipHide t  ## because button disappears from DOM
    t.fit.set 'page'
    t.renderPage?()
