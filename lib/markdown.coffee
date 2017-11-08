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
    @hljs = require 'highlight.js'
    @markdownIt = require('markdown-it')
      html: true
      linkify: true
      typographer: true
      highlight: (str, lang) ->
        if lang and hljs.getLanguage lang
          try
            return hljs.highlight(lang, str).value
        ''  ## default escaping
    .use require 'markdown-it-replacements'
    markdownIt.linkify
    .add 'coauthor:', validate: ///^#{coauthorLinkBodyRe}///
    @markdown = (text) -> markdownIt.render text
    @markdownInline = (text) -> markdownIt.renderInline text
