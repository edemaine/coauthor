## https://github.com/djedi23/meteor-sanitize-html/
## https://github.com/punkave/sanitize-html

@sanitizeHtml = require 'sanitize-html'

sanitizeHtml.defaults.allowedAttributes['*'] = [
  'style', 'class', 'title', 'aria-*'
]

sanitizeHtml.defaults.allowedTags.push 'img'
sanitizeHtml.defaults.allowedAttributes.img.push 'alt', 'width', 'height'
sanitizeHtml.defaults.allowedAttributes.a.push 'title'

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
sanitizeHtml.defaults.allowedTags.push 's'

## LaTeX features
sanitizeHtml.defaults.allowedTags.push 'u'  ## \underline

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
