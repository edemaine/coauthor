## https://github.com/djedi23/meteor-sanitize-html/
## https://github.com/punkave/sanitize-html

sanitizeHtml.defaults.allowedTags.push 'img'
sanitizeHtml.defaults.allowedAttributes.img.push 'alt', 'title'
sanitizeHtml.defaults.allowedAttributes.a.push 'title'
