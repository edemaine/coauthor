pdf2svg = false  ## controls pdf.js rendering mode

Template.messagePDF.onCreated ->
  @page = new ReactiveVar 1
  @pages = new ReactiveVar 1
  @progress = new ReactiveVar null
  @rendering = new ReactiveVar false

Template.messagePDF.onDestroyed ->
  `import('/imports/disappear')`.then (disappear) =>
    disappear.untrack @container

Template.messagePDF.onRendered ->
  @container = @find 'div.pdf'
  window.addEventListener 'resize', _.debounce (=> @resize?()), 100
  `import('pdfjs-dist')`.then (pdfjs) =>
    pdfjs.GlobalWorkerOptions.workerSrc = '/pdf.worker.min.js'  ## in /public
    @autorun =>
      file = Template.currentData()
      size = findFile(file).length
      @progress.set 0
      loader = pdfjs.getDocument urlToInternalFile file
      loader.onProgress = (data) =>
        @progress.set Math.round 100 * data.loaded / size
      loader.then (pdf) =>
        @progress.set null
        @pages.set pdf.numPages
        @track =
          node: @container
          appear: => @resize() #; console.log 'hi', msg.file
          disappear: => @container.innerHTML = '' #; console.log 'bye', msg.file
        @renderPage = =>
          pdf.getPage(@page.get()).then (page) =>
            viewport = page.getViewport 1
            @resize = =>
              ## Simulate width: 100%
              width = @container.parentElement.clientWidth
              height = width * viewport.height / viewport.width
              ## Simulate max-height: 100vh
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
                ## Cancel any ongoing page render, then render the page.
                @renderTask.cancel() if @renderTask?
                @rendering.set true
                @renderTask = page.render
                  canvasContext: context
                  viewport: page.getViewport dpiScale * width / viewport.width
                renderTask = @renderTask
                @renderTask.then (=>
                  ## Replace existing canvas with this one, if still fresh.
                  if renderTask == @renderTask
                    @container.innerHTML = ''
                    @container.appendChild canvas
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

Template.messagePDF.events
  'click .prevPage': (e, t) ->
    if t.page.get() > 1
      t.page.set t.page.get() - 1
      t.renderPage?()
  'click .nextPage': (e, t) ->
    if t.page.get() < t.pages.get()
      t.page.set t.page.get() + 1
      t.renderPage?()
