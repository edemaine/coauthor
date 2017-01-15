## https://github.com/djedi23/meteor-sanitize-html/
## https://github.com/punkave/sanitize-html

@sanitizeHtml = require 'sanitize-html'

sanitizeHtml.defaults.allowedTags.push 'img'
sanitizeHtml.defaults.allowedAttributes.img.push 'alt', 'title', 'width', 'height'
sanitizeHtml.defaults.allowedAttributes.a.push 'title'

sanitizeHtml.defaults.allowedTags.push 'span'
sanitizeHtml.defaults.allowedAttributes.span = ['style', 'class', 'title', 'aria-hidden']

sanitizeHtml.defaults.allowedTags.push 'video'
sanitizeHtml.defaults.allowedAttributes.video = ['controls']
sanitizeHtml.defaults.allowedTags.push 'source'
sanitizeHtml.defaults.allowedAttributes.source = ['src']
sanitizeHtml.defaults.selfClosing.push 'source'
sanitizeHtml.defaults.allowedTags.push 'del'  ## for Markdown ~~strikethrough~~

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
