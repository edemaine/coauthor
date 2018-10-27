## https://github.com/djedi23/meteor-sanitize-html/
## https://github.com/punkave/sanitize-html

sanitizeHtml = require 'sanitize-html'

sanitizeHtml.defaults.allowIframeRelativeUrls = false

sanitizeHtml.defaults.allowedAttributes['*'] = [
  'style', 'class', 'title', 'aria-*', 'data-id'
]

## For author links + drag support
sanitizeHtml.defaults.allowedAttributes.a.push 'data-username'

sanitizeHtml.defaults.allowedTags.push 'img'
sanitizeHtml.defaults.allowedAttributes.img.push 'alt', 'width', 'height'

sanitizeHtml.defaults.allowedTags.push 'span'

sanitizeHtml.defaults.allowedTags.push 'video'
sanitizeHtml.defaults.allowedAttributes.video = ['controls']
sanitizeHtml.defaults.allowedTags.push 'source'
sanitizeHtml.defaults.allowedAttributes.source = ['src']
sanitizeHtml.defaults.selfClosing.push 'source'

## Additional Markdown features
sanitizeHtml.defaults.allowedTags.push 'h1', 'h2', 'h3', 'h4', 'h5', 'h6'
sanitizeHtml.defaults.allowedTags.push 'del'  ## ~~strikethrough~~

## Additional HTML features
sanitizeHtml.defaults.allowedTags.push 's', 'u', 'tt'
sanitizeHtml.defaults.allowedAttributes.ol = ['start']

## SVG, based on
## https://github.com/alnorris/SVG-Sanitizer/blob/master/SvgSanitizer.php
sanitizeHtml.defaults.allowedTags.push 'circle', 'clipPath', 'defs',
  'desc', 'ellipse', 'feGaussianBlur', 'filter', 'foreignObject', 'g',
  'image', 'line', 'linearGradient', 'marker', 'mask', 'metadata', 'path',
  'pattern', 'polygon', 'polyline', 'radialGradient', 'rect', 'stop', 'svg',
  'switch', 'text', 'textPath', 'title', 'tspan', 'use'
#sanitizeHtml.defaults.allowedAttributes.a = ["clip-path", "clip-rule", "fill", "fill-opacity", "fill-rule", "filter", "id", "mask", "opacity", "stroke", "stroke-dasharray", "stroke-dashoffset", "stroke-linecap", "stroke-linejoin", "stroke-miterlimit", "stroke-opacity", "stroke-width", "systemlanguage", "transform", "href", "xlink:href", "xlink:title"]
sanitizeHtml.defaults.allowedAttributes.circle = ["clip-path", "clip-rule", "cx", "cy", "fill", "fill-opacity", "fill-rule", "filter", "id", "mask", "opacity", "r", "requiredfeatures", "stroke", "stroke-dasharray", "stroke-dashoffset", "stroke-linecap", "stroke-linejoin", "stroke-miterlimit", "stroke-opacity", "stroke-width", "systemlanguage", "transform"]
sanitizeHtml.defaults.allowedAttributes.clippath = ["clippathunits", "id"]
#sanitizeHtml.defaults.allowedAttributes.style  = ["type"]
sanitizeHtml.defaults.allowedAttributes.ellipse = ["clip-path", "clip-rule", "cx", "cy", "fill", "fill-opacity", "fill-rule", "filter", "id", "mask", "opacity", "requiredfeatures", "rx", "ry", "stroke", "stroke-dasharray", "stroke-dashoffset", "stroke-linecap", "stroke-linejoin", "stroke-miterlimit", "stroke-opacity", "stroke-width", "systemlanguage", "transform"]
sanitizeHtml.defaults.allowedAttributes.fegaussianblur = ["color-interpolation-filters", "id", "requiredfeatures", "stddeviation"]
sanitizeHtml.defaults.allowedAttributes.filter = ["color-interpolation-filters", "filterres", "filterunits", "height", "id", "primitiveunits", "requiredfeatures", "width", "x", "xlink:href", "y"]
sanitizeHtml.defaults.allowedAttributes.foreignobject = ["font-size", "height", "id", "opacity", "requiredfeatures", "transform", "width", "x", "y"]
sanitizeHtml.defaults.allowedAttributes.g = ["clip-path", "clip-rule", "id", "display", "fill", "fill-opacity", "fill-rule", "filter", "mask", "opacity", "requiredfeatures", "stroke", "stroke-dasharray", "stroke-dashoffset", "stroke-linecap", "stroke-linejoin", "stroke-miterlimit", "stroke-opacity", "stroke-width", "systemlanguage", "transform", "font-family", "font-size", "font-style", "font-weight", "text-anchor"]
sanitizeHtml.defaults.allowedAttributes.image = ["clip-path", "clip-rule", "filter", "height", "id", "mask", "opacity", "requiredfeatures", "systemlanguage", "transform", "width", "x", "xlink:href", "xlink:title", "y"]
sanitizeHtml.defaults.allowedAttributes.line = ["clip-path", "clip-rule", "fill", "fill-opacity", "fill-rule", "filter", "id", "marker-end", "marker-mid", "marker-start", "mask", "opacity", "requiredfeatures", "stroke", "stroke-dasharray", "stroke-dashoffset", "stroke-linecap", "stroke-linejoin", "stroke-miterlimit", "stroke-opacity", "stroke-width", "systemlanguage", "transform", "x1", "x2", "y1", "y2"]
sanitizeHtml.defaults.allowedAttributes.lineargradient = ["id", "gradienttransform", "gradientunits", "requiredfeatures", "spreadmethod", "systemlanguage", "x1", "x2", "xlink:href", "y1", "y2"]
sanitizeHtml.defaults.allowedAttributes.marker = ["id", "markerheight", "markerunits", "markerwidth", "orient", "preserveaspectratio", "refx", "refy", "systemlanguage", "viewbox"]
sanitizeHtml.defaults.allowedAttributes.mask = ["height", "id", "maskcontentunits", "maskunits", "width", "x", "y"]
sanitizeHtml.defaults.allowedAttributes.metadata = ["id"]
sanitizeHtml.defaults.allowedAttributes.path = ["clip-path", "clip-rule", "d", "fill", "fill-opacity", "fill-rule", "filter", "id", "marker-end", "marker-mid", "marker-start", "mask", "opacity", "requiredfeatures", "stroke", "stroke-dasharray", "stroke-dashoffset", "stroke-linecap", "stroke-linejoin", "stroke-miterlimit", "stroke-opacity", "stroke-width", "systemlanguage", "transform"]
sanitizeHtml.defaults.allowedAttributes.pattern = ["height", "id", "patterncontentunits", "patterntransform", "patternunits", "requiredfeatures", "systemlanguage", "viewbox", "width", "x", "xlink:href", "y"]
sanitizeHtml.defaults.allowedAttributes.polygon = ["clip-path", "clip-rule", "id", "fill", "fill-opacity", "fill-rule", "filter", "id", "marker-end", "marker-mid", "marker-start", "mask", "opacity", "points", "requiredfeatures", "stroke", "stroke-dasharray", "stroke-dashoffset", "stroke-linecap", "stroke-linejoin", "stroke-miterlimit", "stroke-opacity", "stroke-width", "systemlanguage", "transform"]
sanitizeHtml.defaults.allowedAttributes.polyline = ["clip-path", "clip-rule", "id", "fill", "fill-opacity", "fill-rule", "filter", "marker-end", "marker-mid", "marker-start", "mask", "opacity", "points", "requiredfeatures", "stroke", "stroke-dasharray", "stroke-dashoffset", "stroke-linecap", "stroke-linejoin", "stroke-miterlimit", "stroke-opacity", "stroke-width", "systemlanguage", "transform"]
sanitizeHtml.defaults.allowedAttributes.radialgradient = ["cx", "cy", "fx", "fy", "gradienttransform", "gradientunits", "id", "r", "requiredfeatures", "spreadmethod", "systemlanguage", "xlink:href"]
sanitizeHtml.defaults.allowedAttributes.rect = ["clip-path", "clip-rule", "fill", "fill-opacity", "fill-rule", "filter", "height", "id", "mask", "opacity", "requiredfeatures", "rx", "ry", "stroke", "stroke-dasharray", "stroke-dashoffset", "stroke-linecap", "stroke-linejoin", "stroke-miterlimit", "stroke-opacity", "stroke-width", "systemlanguage", "transform", "width", "x", "y"]
sanitizeHtml.defaults.allowedAttributes.stop = ["id", "offset", "requiredfeatures", "stop-color", "stop-opacity", "systemlanguage"]
sanitizeHtml.defaults.allowedAttributes.svg = ["clip-path", "clip-rule", "filter", "id", "height", "mask", "preserveaspectratio", "requiredfeatures", "systemlanguage", "viewbox", "width", "x", "xmlns", "xmlns:se", "xmlns:xlink", "y"]
sanitizeHtml.defaults.allowedAttributes.switch = ["id", "requiredfeatures", "systemlanguage"]
sanitizeHtml.defaults.allowedAttributes.symbol = ["fill", "fill-opacity", "fill-rule", "filter", "font-family", "font-size", "font-style", "font-weight", "id", "opacity", "preserveaspectratio", "requiredfeatures", "stroke", "stroke-dasharray", "stroke-dashoffset", "stroke-linecap", "stroke-linejoin", "stroke-miterlimit", "stroke-opacity", "stroke-width", "systemlanguage", "transform", "viewbox"]
sanitizeHtml.defaults.allowedAttributes.text = ["clip-path", "clip-rule", "fill", "fill-opacity", "fill-rule", "filter", "font-family", "font-size", "font-style", "font-weight", "id", "mask", "opacity", "requiredfeatures", "stroke", "stroke-dasharray", "stroke-dashoffset", "stroke-linecap", "stroke-linejoin", "stroke-miterlimit", "stroke-opacity", "stroke-width", "systemlanguage", "text-anchor", "transform", "x", "xml:space", "y"]
sanitizeHtml.defaults.allowedAttributes.textpath = ["id", "method", "requiredfeatures", "spacing", "startoffset", "systemlanguage", "transform", "xlink:href"]
sanitizeHtml.defaults.allowedAttributes.tspan = ["clip-path", "clip-rule", "dx", "dy", "fill", "fill-opacity", "fill-rule", "filter", "font-family", "font-size", "font-style", "font-weight", "id", "mask", "opacity", "requiredfeatures", "rotate", "stroke", "stroke-dasharray", "stroke-dashoffset", "stroke-linecap", "stroke-linejoin", "stroke-miterlimit", "stroke-opacity", "stroke-width", "systemlanguage", "text-anchor", "textlength", "transform", "x", "xml:space", "y"]
sanitizeHtml.defaults.allowedAttributes.use = ["clip-path", "clip-rule", "fill", "fill-opacity", "fill-rule", "filter", "height", "id", "mask", "stroke", "stroke-dasharray", "stroke-dashoffset", "stroke-linecap", "stroke-linejoin", "stroke-miterlimit", "stroke-opacity", "stroke-width", "transform", "width", "x", "xlink:href", "y"]

## KaTeX/MathML
## (tag list from https://developer.mozilla.org/en-US/docs/Web/MathML/Element)
sanitizeHtml.defaults.allowedTags.push 'math', 'annotation', 'semantics',
  'menclose', 'mfenced', 'mfrac', 'mglyph', 'mi', 'mlabeledtr',
  'mmultiscripts', 'mn', 'mo', 'mover', 'mpadded', 'mphantom', 'mroot',
  'mrow', 'mspace', 'msub', 'msup', 'msubsup', 'msqrt', 'mstyle', 'mtable',
  'mtd', 'mtext', 'mtr', 'munder', 'munderover'
sanitizeHtml.defaults.allowedAttributes.annotation = ['encoding']
sanitizeHtml.defaults.allowedAttributes.menclose = ['notation']
sanitizeHtml.defaults.allowedAttributes.mfrac = ['linethickness']
sanitizeHtml.defaults.allowedAttributes.mi = ['mathvariant']
sanitizeHtml.defaults.allowedAttributes.mo = ['fence', 'separator', 'stretchy']
sanitizeHtml.defaults.allowedAttributes.mstyle = ['mathcolor']
sanitizeHtml.defaults.allowedTags.push 'nobr'

## https://stackoverflow.com/questions/9329552/explain-regex-that-finds-css-comments
cssCommentRegex = "\\/\\*[^*]*\\*+(?:[^/*][^*]*\\*+)*\\/"
cssBlankRegex = "(?:\\s|#{cssCommentRegex})*"

## We used to always forbid position:absolute/fixed, but KaTeX needs them
## (see e.g. `\not`).  Now we just ensure the containing block is reasonable.
#sanitizeHtml.defaults.transformTags =
#  '*': (tagName, attribs) ->
#    if attribs.style? and
#       ///\bposition#{cssBlankRegex}:#{cssBlankRegex}(absolute|fixed)///i.test(
#         attribs.style)
#      delete attribs.style
#    tagName: tagName
#    attribs: attribs

jsdiff = require 'diff'

maxDiffSize = 200

@sanitize = (html) ->
  sanitized = sanitizeHtml html
  if Meteor.isClient and sanitized != html
    context = ''
    if html.length + sanitized.length < maxDiffSize
      diffs =
        for diff in jsdiff.diffChars html, sanitized
          if diff.removed
            "?#{diff.value}?"
          else if diff.added
            "!#{diff.value}!"
          else
            if diff.value.length > 40
              diff.value = diff.value[...20] + "..." + diff.value[diff.value.length-20..]
            diff.value
      console.warn "Sanitized", diffs.join ''
    else
      console.warn "Sanitized",
        before: html
        after: sanitized
  sanitized
