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
    .add 'coauthor:', validate: ///^#{coauthorLinkBodyHashRe}///
    @markdown = (text) -> markdownIt.render text
    @markdownInline = (text) -> markdownIt.renderInline text
    @linkify = (text) ->
      links = markdownIt.linkify.match text
      if links?
        existing = []
        linkRe = /<\s*a\b[^]*<\s*\/a\s*>/g
        while match = linkRe.exec text
          existing.push [match.index, match.index + match[0].length]
        links.reverse()
        for link in links
          ## Don't convert links in tags
          continue if inTag text, link.index
          ## Don't convert links already linked
          linked = false
          for [begin, end] in existing
            if begin <= link.index <= end
              linked = true
              break
          continue if linked
          text = text[...link.index] +
            """<a href="#{link.url}">#{link.text}</a>""" +
            text[link.lastIndex..]
      text
