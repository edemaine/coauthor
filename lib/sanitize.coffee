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
#sanitizeHtml.defaults.allowedTags.push 'math', 'semantics', 'menclose', 'mfrac', 'mi', 'mn', 'mo', 'mrow', 'msqrt', 'annotation'
#sanitizeHtml.defaults.allowedAttributes.menclose = ['notation']
#sanitizeHtml.defaults.allowedAttributes.annotation = ['encoding']
