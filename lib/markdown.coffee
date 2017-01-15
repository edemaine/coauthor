#markdownMode = 'marked'
markdownMode = 'markdown-it'

switch markdownMode

  when 'marked'
    marked.setOptions
      smartypants: true
    marked.InlineLexer.rules.gfm.url =
      ///^((coauthor:/?/?|https?://)[^\s<]+[^<.,:;"')\]\s])///
    @markdown = marked
    @markdownInline = (text) -> marked.inlineLexer text, {}, marked.defaults

  when 'markdown-it'
    md = require('markdown-it')
      html: true
      linkify: true
      typographer: true
    @markdown = (text) -> md.render text
    @markdownInline = (text) -> md.renderInline text
