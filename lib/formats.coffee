@availableFormats = ['markdown', 'latex', 'html']  ## 'file' not an option for user
@mathjaxFormats = availableFormats  ## Don't do tex2jax for files

if Meteor.isClient
  Template.registerHelper 'formats', ->
    for format in availableFormats
      format: format
      active: if Template.currentData()?.format == format then 'active' else ''
      capitalized: capitalize format

## Finds all $...$ and $$...$$ blocks, where ... properly deals with balancing
## braces (e.g. $\hbox{$x$}$) and escaped dollar signs (\$ doesn't count as $),
## and replaces them with the output of the given replacer function.
replaceMathBlocks = (text, replacer) ->
  blocks = []
  re = /[${}]|\\./g
  start = null
  braces = 0
  while (match = re.exec text)?
    #console.log match
    switch match[0]
      when '$'
        if start?  ## already in $ block
          if match.index > start+1  ## not opening $$
            if braces == 0  ## ignore $ nested within braces e.g. \text{$x$}
              blocks.push
                start: start
                end: match.index
              start = null
        else  ## not in $ block
          if blocks.length > 0 and blocks[blocks.length-1].end+1 == match.index
            ## second $ terminator
            blocks[blocks.length-1].end = match.index  ## closing $$
          else  ## starting $ block
            braces = 0
            start = match.index
      when '{'
        braces += 1
      when '}'
        braces -= 1
        braces = 0 if braces < 0  ## ignore extra }s
  if blocks.length > 0
    out = text[...blocks[0].start]
    for block, i in blocks
      out += replacer text[block.start..block.end]
      if i < blocks.length-1
        out += text[block.end+1...blocks[i+1].start]
      else
        out += text[block.end+1..]
    out
  else
    text

latex2html = (tex) ->
  defs = {}
  tex = tex.replace /%.*$\n?/mg, ''
  tex = tex.replace /\\def\s*\\([a-zA-Z]+)\s*{((?:[^{}]|{[^{}]*})*)}/g, (match, p1, p2) ->
    defs[p1] = p2
    ''
  for def, val of defs
    console.log def, val
    tex = tex.replace new RegExp("\\\\#{def}\\s*", 'g'), val
  tex = '<p>' + tex
  .replace /\\\\/g, '[DOUBLEBACKSLASH]'
  .replace /\\(BY|YEAR)\s*{([^{}]*)}/g, '<span style="border: thin solid; margin-left: 0.5em; padding: 0px 4px; font-variant:small-caps">$2</span>'
  .replace /\\protect\s*/g, ''
  .replace /\\textbf\s*{([^{}]*)}/g, '<b>$1</b>'
  .replace /\\textit\s*{([^{}]*)}/g, '<i>$1</i>'
  .replace /\\textsf\s*{([^{}]*)}/g, '<span style="font-family: sans-serif">$1</I>'
  .replace /\\emph\s*{([^{}]*)}/g, '<em>$1</em>'
  .replace /\\textsc\s*{([^{}]*)}/g, '<span style="font-variant:small-caps">$1</span>'
  .replace /\\url\s*{([^{}]*)}/g, '<a href="$1">$1</a>'
  .replace /\\href\s*{([^{}]*)}\s*{([^{}]*)}/g, '<a href="$1">$2</a>'
  .replace /\\textcolor\s*{([^{}]*)}\s*{([^{}]*)}/g, '<span style="color: $1">$2</a>'
  .replace /\\colorbox\s*{([^{}]*)}\s*{([^{}]*)}/g, '<span style="background-color: $1">$2</a>'
  .replace /\\begin\s*{enumerate}/g, '<ol>'
  .replace /\\begin\s*{itemize}/g, '<ul>'
  .replace /\\item/g, '<li>'
  .replace /\\end\s*{enumerate}/g, '</ol>'
  .replace /\\end\s*{itemize}/g, '</ul>'
  .replace /\\chapter\s*\*?\s*{([^{}]*)}/g, '<h1>$1</h1>'
  .replace /\\section\s*\*?\s*{([^{}]*)}/g, '<h2>$1</h2>'
  .replace /\\subsection\s*\*?\s*{([^{}]*)}/g, '<h3>$1</h3>'
  .replace /\\subsubsection\s*\*?\s*{([^{}]*)}/g, '<h4>$1</h4>'
  .replace /\\footnote\s*{((?:[^{}]|{[^{}]*})*)}/g, '[$1]'
  .replace /\\includegraphics\s*{([^{}]*)}/g, '<img src="$1">'
  .replace /\\begin\s*{(problem|theorem|conjecture|lemma|corollary)}/g, (m, p1) -> "<blockquote><b>#{s.capitalize p1}:</b> "
  .replace /\\end\s*{(problem|theorem|conjecture|lemma|corollary)}/g, '</blockquote>'
  .replace /``/g, '&ldquo;'
  .replace /''/g, '&rdquo;'
  #.replace /`/g, '&lsquo;'
  #.replace /'/g, '&rsquo;'
  .replace /\\"{(.)}/g, '&$1uml;'
  .replace /\\"(.)/g, '&$1uml;'
  .replace /\\'{(.)}/g, '&$1acute;'
  .replace /\\'(.)/g, '&$1acute;'
  .replace /\\`{(.)}/g, '&$1grave;'
  .replace /\\`(.)/g, '&$1grave;'
  .replace /\\^{(.)}/g, '&$1circ;'
  .replace /\\^(.)/g, '&$1circ;'
  .replace /\\~{(.)}/g, '&$1tilde;'
  .replace /\\~(.)/g, '&$1tilde;'
  .replace /\\'c|\\'{c}/g, '&#263;'
  .replace /\\'n|\\'{n}/g, '&#324;'
  .replace /\\c\s*{s}/g, '&#351;'
  .replace /\\c\s*{z}/g, 'z'  ## doesn't exist
  .replace /\\v\s*{C}/g, '&#268;'
  .replace /\\v\s*{s}/g, '&#353;'
  .replace /\\v\s*{n}/g, '&#328;'
  .replace /\\v\s*{r}/g, '&#345;'
  .replace /\\u\s*{a}/g, '&#259;'
  .replace /\\v\s*{a}/g, '&#462;'
  .replace /\\H\s*{o}/g, '&#337;'
  .replace /\\&/g, '&amp;'
  .replace /~/g, '&nbsp;'
  .replace /\\\s/g, ' '
  .replace /---/g, '&mdash;'
  .replace /--/g, '&ndash;'
  .replace /\n\n+/g, '\n<p>\n'
  .replace /<p>\s*(<h[1-9]>)/g, '$1'
  .replace /\[DOUBLEBACKSLASH\]/g, '\\\\'

@formats =
  file: (text, title) ->
    return text if title
    file = findFile text
    if file?
      if file.contentType[...6] == 'image/'
        text = """<img src="#{urlToFile file}">"""
      else if file.contentType in ['video/mp4', 'video/ogg', 'video/webm']
        text = """<video controls><source src="#{urlToFile file}" type="#{file.contentType}"></video>"""
      else
        text = """<i class="odd-file"><a href="#{urlToFile file}">&lt;#{file.length}-byte #{file.contentType} file&gt;</a></i>"""
    else
      text = """<i class="bad-file">&lt;unknown file with ID #{text}&gt;</i>"""
  markdown: (text, title) ->
    ## Escape all characters that can be (in particular, _s) that appear
    ## inside math mode, to prevent Marked from processing them.
    ## The Regex is exactly marked.js's inline.escape.
    text = replaceMathBlocks text, (block) ->
      block.replace /[\\`*{}\[\]()#+\-.!_]/g, '\\$&'
    #marked.Lexer.rules = {text: /^[^\n]+/} if title
    if title  ## use "single-line" version of Markdown
      text = markdownInline text
    else
      text = markdown text
  latex: (text, title) ->
    latex2html text
  html: (text, title) ->
    text

@coauthorLinkBodyRe = "/?/?([a-zA-Z0-9]+)"
@coauthorLinkRe = "coauthor:#{coauthorLinkBodyRe}"

postprocessCoauthorLinks = (text) ->
  ## xxx Not reactive, but should be.  E.g. won't update if image replaced.
  ## xxx More critically, won't load anything outside current subscription...
  text.replace ///(<img\s[^<>]*src\s*=\s*['"])#{coauthorLinkRe}///ig,
    (match, p1, p2) ->
      msg = Messages.findOne p2
      if msg? and msg.format == 'file'
        p1 + urlToFile msg.body
      else
        if msg?
          console.warn "Couldn't detect image in message #{p2} -- must be text?"
        else
          console.warn "Couldn't find group for message #{p2} (likely subscription issue)", msg
        match
  .replace ///(<a\s[^<>]*href\s*=\s*['"])#{coauthorLinkRe}///ig,
    (match, p1, p2) ->
      msg = Messages.findOne p2
      if msg?
        p1 + pathFor 'message',
          group: msg.group
          message: msg._id
      else
        console.warn "Couldn't find group for message #{p2} (likely subscription issue)"
        match

katex = require 'katex'

postprocessKatex = (text) ->
  replaceMathBlocks text, (block) ->
    start$ = /^\$+/.exec block
    end$ = /\$+$/.exec block
    display = start$[0].length >= 2
    block = block[start$[0].length...end$.index]
    .replace /&lt;/g, '<'
    .replace /&gt;/g, '>'
    .replace /’/g, "'"
    .replace /‘/g, "`"  ## remove bad Marked automatic behavior
    try
      katex.renderToString block,
        displayMode: display
        throwOnError: false
        macros:
          '\\dots': '\\ldots'
      #.replace /<math>.*<\/math>/, ''  ## remove MathML
    catch e
      throw e unless e instanceof katex.ParseError
      #console.warn "KaTeX failed to parse $#{block}$: #{e}"
      title = e.toString()
      .replace /&/g, '&amp;'
      .replace /'/g, '&#39;'
      latex = block
      .replace /&/g, '&amp;'
      .replace /</g, '&lt;'
      .replace />/g, '&gt;'
      "<SPAN CLASS='katex-error' TITLE='#{title}'>#{latex}</SPAN>"

postprocess = (text, keepTeX = false) ->
  text = postprocessKatex text unless keepTeX
  postprocessCoauthorLinks text

jsdiff = require 'diff'

@sanitize = (html) ->
  sanitized = sanitizeHtml html
  if Meteor.isClient and sanitized != html
    context = ''
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
    #console.warn "Sanitized",
    #  before: html
    #  after: sanitized
  sanitized

@formatBody = (format, body, leaveTeX = false) ->
  if format of formats
    body = formats[format] body, false
  else
    console.warn "Unrecognized format '#{format}'"
  sanitize postprocess body, leaveTeX

@formatTitle = (format, title, leaveTeX = false) ->
  if format of formats
    title = formats[format] title, true
  else
    console.warn "Unrecognized format '#{format}'"
  ## Remove surrounding <P> block caused by Markdown and LaTeX formatters.
  title = title
  .replace /^\s*<P>\s*/i, ''
  .replace /\s*<\/P>\s*$/i, ''
  sanitize postprocess title, leaveTeX

@stripHTMLTags = (html) ->
  html.replace /<[^>]*>/gm, ''

@indentLines = (text, indent) ->
  text.replace /^/gm, indent
