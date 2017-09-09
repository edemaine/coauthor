## https://github.com/djedi23/meteor-sanitize-html/
## https://github.com/punkave/sanitize-html

sanitizeHtml = require 'sanitize-html'

sanitizeHtml.defaults.allowedAttributes['*'] = [
  'style', 'class', 'title', 'aria-*'
]

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
sanitizeHtml.defaults.allowedAttributes.mo = ['fence', 'separator']
sanitizeHtml.defaults.allowedAttributes.mstyle = ['mathcolor']
sanitizeHtml.defaults.allowedTags.push 'nobr'

sanitizeHtml.defaults.transformTags =
  '*': (tagName, attribs) ->
    if attribs.style? and /\bposition\s*:/i.test attribs.style
      delete attribs.style
    tagName: tagName
    attribs: attribs

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
