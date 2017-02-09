@availableFormats = ['markdown', 'latex', 'html']
@mathjaxFormats = availableFormats

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
  #console.log text
  blocks = []
  re = /[{}]|\$\$?|\\(begin|end)\s*{(equation|eqnarray|align)\*?}|\\./g
  block = null
  startBlock = (b) ->
    block = b
    block.start = match.index
    block.contentStart = match.index + match[0].length
  endBlock = ->
    block.content = text[block.contentStart...match.index]
    delete block.contentStart  ## no longer needed
    ## Simulate \begin{align}...\end{align} with \begin{aligned}...\end{aligned}
    if block.environment and block.environment in ['eqnarray', 'align']
      block.content = "\\begin{aligned}#{block.content}\\end{aligned}"
    block.end = match.index + match[0].length
    block.all = text[block.start...block.end]
    blocks.push block
    block = null
  braces = 0
  while (match = re.exec text)?
    #console.log '>', match
    switch match[0]
      when '$', '$$'
        if block?  ## already in math block => closing
          if braces == 0  ## ignore $ nested within braces e.g. \text{$x$}
            endBlock()
        else  ## not in math block => opening
          startBlock
            display: match[0].length > 1  ## $$?
          braces = 0
      when '\\(', '\\['
        if braces == 0 and not block?
          startBlock
            display: match[0][1] == '['
      when '\\)', '\\]'
        if braces == 0 and block?
          endBlock()
      when '{'
        braces += 1
      when '}'
        braces -= 1
        braces = 0 if braces < 0  ## ignore extra }s
      else
        if match[1] == 'begin' and not block?
          startBlock
            display: true
            environment: match[2]
        else if match[1] == 'end' and block?
          if braces == 0
            endBlock()
  if blocks.length > 0
    out = text[...blocks[0].start]
    for block, i in blocks
      out += replacer block
      if i < blocks.length-1
        out += text[block.end...blocks[i+1].start]
      else
        out += text[block.end..]
    out
  else
    text

inTag = (string, offset) ->
  open = string.lastIndexOf '<', offset
  if open >= 0
    close = string.lastIndexOf '>', offset
    if close < open  ## potential unclosed HTML tag
      return true
  false

latexSymbols =
  '``': '&ldquo;'
  "''": '&rdquo;'
  '"': '&rdquo;'
  '`': '&lsquo;'
  "'": '&rsquo;'
  '~': '&nbsp;'
  '---': '&mdash;'
  '--': '&ndash;'
latexSymbolsRe = ///#{_.keys(latexSymbols).join '|'}///g
latexEscape = (x) ->
  x.replace /[-`'~\\$%&<>]/g, (char) -> "&##{char.charCodeAt 0};"

@latex2html = (tex) ->
  ## Parse verbatim first (to avoid contents getting mangled by other parsing).
  tex = tex.replace /\\begin\s*{verbatim}([^]*?)\\end\s*{verbatim}/g,
    (match, verb) -> "<pre>#{latexEscape verb}</pre>"
  ## Also parse URLs first, to allow for weird characters in URLs (e.g. %)
  tex = tex.replace /\\url\s*{([^{}]*)}/g, (match, url) ->
    """<a href="#{url}">#{latexEscape url}</a>"""
  .replace /\\href\s*{([^{}]*)}\s*{((?:[^{}]|{[^{}]*})*)}/g, '<a href="$1">$2</a>'
  ## Now remove comments, stripping newlines from the input.
  comments = (text) ->
    text = text.replace /%.*$\n?/mg, (match, offset, string) ->
      if inTag string, offset
        ## Potential unclosed HTML tag: leave alone, but process other
        ## %s on the same line after tag closes.
        close = match.indexOf '>'
        if close >= 0
          match[..close] + comments match[close+1..]
        else
          match
      else
        ''
  tex = comments tex
  ## Paragraph detection must go before any macro expansion (which eat \n's)
  tex = tex.replace /\n\n+/g, '\n\\par\n'
  ## Process \def and \let, and expand all macros.
  defs = {}
  tex = tex.replace /\\def\s*\\([a-zA-Z]+)\s*{((?:[^{}]|{(?:[^{}]|{[^{}]*})*})*)}/g, (match, p1, p2) ->
    defs[p1] = p2
    ''
  tex = tex.replace /\\let\s*\\([a-zA-Z]+)\s*=?\s*\\([a-zA-Z]+)\s*/g, (match, p1, p2) ->
    defs[p1] = "\\#{p2}"
    ''
  #for def, val of defs
  #  console.log "\\#{def} = #{val}"
  if 0 < _.size defs
    r = ///\\(#{_.keys(defs).join '|'})\s*///g
    while 0 <= tex.search(r)
      tex = tex.replace r, (match, def) -> defs[def]
  ## After \def expansion and verbatim processing, protect math
  [tex, math] = preprocessKaTeX tex
  ## Start initial paragraph
  tex = '<p>' + tex
  ## Commands
  tex = tex.replace /\\\\/g, '[DOUBLEBACKSLASH]'
  .replace /\\(BY|YEAR)\s*{([^{}]*)}/g, '<span style="border: thin solid; margin-left: 0.5em; padding: 0px 4px; font-variant:small-caps">$2</span>'
  .replace /\\protect\b\s*/g, ''
  .replace /\\par\b\s*/g, '<p>'
  .replace /\\textbf\s*{((?:[^{}]|{[^{}]*})*)}/g, '<b>$1</b>'
  .replace /\\textit\s*{((?:[^{}]|{[^{}]*})*)}/g, '<i>$1</i>'
  .replace /\\textsf\s*{((?:[^{}]|{[^{}]*})*)}/g, '<span style="font-family: sans-serif">$1</span>'
  .replace /\\emph\s*{((?:[^{}]|{[^{}]*})*)}/g, '<em>$1</em>'
  .replace /\\textsc\s*{((?:[^{}]|{[^{}]*})*)}/g, '<span style="font-variant:small-caps">$1</span>'
  .replace /\\underline\s*{((?:[^{}]|{[^{}]*})*)}/g, '<u>$1</u>'
  .replace /\\textcolor\s*{([^{}]*)}\s*{([^{}]*)}/g, '<span style="color: $1">$2</a>'
  .replace /\\colorbox\s*{([^{}]*)}\s*{([^{}]*)}/g, '<span style="background-color: $1">$2</a>'
  .replace /\\begin\s*{enumerate}/g, '<ol>'
  .replace /\\begin\s*{itemize}/g, '<ul>'
  .replace /\\item\b\s*/g, '<li>'
  .replace /\\end\s*{enumerate}/g, '</ol>'
  .replace /\\end\s*{itemize}/g, '</ul>'
  .replace /\\chapter\s*\*?\s*{((?:[^{}]|{[^{}]*})*)}/g, '<h1>$1</h1>'
  .replace /\\section\s*\*?\s*{((?:[^{}]|{[^{}]*})*)}/g, '<h2>$1</h2>'
  .replace /\\subsection\s*\*?\s*{((?:[^{}]|{[^{}]*})*)}/g, '<h3>$1</h3>'
  .replace /\\subsubsection\s*\*?\s*{((?:[^{}]|{[^{}]*})*)}/g, '<h4>$1</h4>'
  .replace /\\paragraph\s*\*?\s*{((?:[^{}]|{[^{}]*})*)}\s*/g, '<p><b>$1</b> '
  .replace /\\footnote\s*{((?:[^{}]|{[^{}]*})*)}/g, '[$1]'
  .replace /\\includegraphics\s*(\[[^\[\]]*\]\s*)?{((?:[^{}]|{[^{}]*})*)}/g,
    (match, optional = '', graphic) ->
      style = ''
      optional.replace /width\s*=\s*([-0-9.]+)\s*([a-zA-Z]*)/g,
        (match2, value, unit) ->
          style += "width: #{value}#{unit};"
          ''
      .replace /height\s*=\s*([-0-9.]+)\s*([a-zA-Z]*)/g,
        (match2, value, unit) ->
          style += "height: #{value}#{unit};"
          ''
      style = ' style="' + style + '"' if style
      """<img src="#{graphic}"#{style}>"""
  .replace /\\pdftooltip\s*{((?:[^{}]|{(?:[^{}]|{[^{}]*})*})*)}\s*{((?:[^{}]|{(?:[^{}]|{[^{}]*})*})*)}/g,
    (match, p1, p2) -> """<span title="#{(putMathBack p2, math).replace /"/g, '&#34;'}">#{p1}</span>"""
  .replace /\\raisebox\s*{\s*([-0-9.]+)\s*([a-zA-Z]*)\s*}{((?:[^{}]|{[^{}]*})*)}/g,
    (match, value, unit, arg) ->
      if value[0] == '-'
        value = value[1..]
      else
        value = "-#{value}"
      """<span style="margin-top: #{value}#{unit};">#{arg}</span>"""
  .replace /\\begin\s*{(problem|theorem|conjecture|lemma|corollary|fact|observation|proposition|claim)}/g, (m, p1) -> "<blockquote><b>#{s.capitalize p1}:</b> "
  .replace /\\end\s*{(problem|theorem|conjecture|lemma|corollary|fact|observation|proposition|claim)}/g, '</blockquote>'
  .replace /\\begin\s*{(proof|pf)}/g, '<b>Proof:</b> '
  .replace /\\end\s*{(proof|pf)}/g, ' &#8718;'
  .replace /\\"{(.)}/g, '&$1uml;'
  .replace /\\"(.)/g, '&$1uml;'
  .replace /\\'c|\\'{c}/g, '&#263;'
  .replace /\\'n|\\'{n}/g, '&#324;'
  .replace /\\'{(.)}/g, '&$1acute;'
  .replace /\\'(.)/g, '&$1acute;'
  .replace /\\`{(.)}/g, '&$1grave;'
  .replace /\\`(.)/g, '&$1grave;'
  .replace /\\^{(.)}/g, '&$1circ;'
  .replace /\\^(.)/g, '&$1circ;'
  .replace /\\~{(.)}/g, '&$1tilde;'
  .replace /\\~(.)/g, '&$1tilde;'
  .replace /\\=a|\\={a}/g, '&#257;'
  .replace /\\=e|\\={e}/g, '&#275;'
  .replace /\\=g|\\={g}/g, '&#7713;'
  .replace /\\=i|\\={i}|\\=\\i\s*|\\={\\i}/g, '&#299;'
  .replace /\\=o|\\={o}/g, '&#333;'
  .replace /\\=u|\\={u}/g, '&#363;'
  .replace /\\=y|\\={y}/g, '&#563;'
  .replace /\\c\s*{s}/g, '&#351;'
  .replace /\\c\s*{z}/g, 'z&#807;'
  .replace /\\v\s*{C}/g, '&#268;'
  .replace /\\v\s*{s}/g, '&#353;'
  .replace /\\v\s*{n}/g, '&#328;'
  .replace /\\v\s*{r}/g, '&#345;'
  .replace /\\u\s*{a}/g, '&#259;'
  .replace /\\v\s*{a}/g, '&#462;'
  .replace /\\H\s*{o}/g, '&#337;'
  .replace /\\&/g, '&amp;'
  .replace /\\([${}])/g, '$1'
  .replace /\\\s+/g, ' '
  .replace latexSymbolsRe, (match, offset, string) ->
    if inTag string, offset  ## potential unclosed HTML tag; leave alone
      match
    else
      latexSymbols[match]
  .replace /<p>\s*(<h[1-9]>)/g, '$1'
  .replace /<p>(\s*<p>)+/g, '<p>'  ## Remove double paragraph breaks
  .replace /\[DOUBLEBACKSLASH\]/g, '\\\\'
  [tex, math]

@formats =
  markdown: (text, title) ->
    ## Escape all characters that can be (in particular, _s) that appear
    ## inside math mode, to prevent Marked from processing them.
    ## The Regex is exactly marked.js's inline.escape.
    #text = replaceMathBlocks text, (block) ->
    #  block.replace /[\\`*{}\[\]()#+\-.!_]/g, '\\$&'
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
      if msg? and msg.file
        p1 + urlToFile msg.file
      else
        if msg?
          console.warn "Couldn't detect image in message #{p2} -- must be text?"
        else
          console.warn "Couldn't find group for message #{p2} (likely subscription issue)"
        match
  .replace ///(<a\s[^<>]*href\s*=\s*['"])#{coauthorLinkRe}///ig,
    (match, p1, p2) ->
      ## xxx Could add msg.title, when available, to hover text...
      ## xxx Currently assuming message is in same group if can't find it.
      msg = Messages.findOne p2
      p1 + urlFor 'message',
        group: msg?.group or routeGroup?() or wildGroup
        message: p2

## URL regular expression with scheme:// required, to avoid extraneous matching
@urlRe = /\w+:\/\/[-\w~!$&'()*+,;=.:@%#?\/]+/g

postprocessLinks = (text) ->
  text.replace urlRe, (match, offset, string) ->
    if inTag string, offset
      match
    else
      match.replace /\/+/g, (slash) ->
        "#{slash}&#8203;"  ## Add zero-width space after every slash group

@escapeRe = (string) ->
  string.replace /[\\^$*+?.()|{}\[\]]/g, "\\$&"

postprocessAtMentions = (text) ->
  return text unless 0 <= text.indexOf '@'
  users = Meteor.users.find {}, fields: username: 1
  .map (user) -> user.username
  return text unless 0 < users.length
  ## Reverse-sort by length to ensure maximum-length match
  ## (to handle when one username is a prefix of another).
  _.sortBy users, (name) -> -name.length
  users = (escapeRe user for user in users)
  text.replace ///@(#{users.join '|'})(?!\w)///g, (match, user) ->
    "@#{linkToAuthor (routeGroup?() ? wildGroup), user}"

katex = require 'katex'

preprocessKaTeX = (text) ->
  math = []
  i = 0
  text = replaceMathBlocks text, (block) ->
    i += 1
    math[i] = block
    "MATH#{i}ENDMATH"
  [text, math]

putMathBack = (tex, math) ->
  ## Restore math
  tex.replace /MATH(\d+)ENDMATH/g, (match, p1) -> math[p1].all

postprocessKaTeX = (text, math) ->
  replacer = (block) ->
    content = block.content
    #.replace /&lt;/g, '<'
    #.replace /&gt;/g, '>'
    #.replace /’/g, "'"
    #.replace /‘/g, "`"  ## remove bad Marked automatic behavior
    try
      katex.renderToString content,
        displayMode: block.display
        throwOnError: false
        macros:
          '\\dots': '\\ldots'
          '\\epsilon': '\\varepsilon'
      #.replace /<math>.*<\/math>/, ''  ## remove MathML
    catch e
      throw e unless e instanceof katex.ParseError
      #console.warn "KaTeX failed to parse $#{content}$: #{e}"
      title = e.toString()
      .replace /&/g, '&amp;'
      .replace /"/g, '&#34;'
      latex = content
      .replace /&/g, '&amp;'
      .replace /</g, '&lt;'
      .replace />/g, '&gt;'
      """<span class="katex-error" title="#{title}">#{latex}</span>"""
  if math?
    text.replace /MATH(\d+)ENDMATH/g, (match, p1) ->
      replacer math[p1]
  else
    replaceMathBlocks text, replacer

formatEither = (isTitle, format, text, leaveTeX = false) ->
  ## LaTeX format is special because it does its own math preprocessing at a
  ## specific time during its formatting.  Other formats don't touch math.
  if format == 'latex'
    [text, math] = formats[format] text, isTitle
  else
    [text, math] = preprocessKaTeX text
    if format of formats
      text = formats[format] text, isTitle
    else
      console.warn "Unrecognized format '#{format}'"
  ## Remove surrounding <P> block caused by Markdown and LaTeX formatters.
  if isTitle
    text = text
    .replace /^\s*<P>\s*/i, ''
    .replace /\s*<\/P>\s*$/i, ''
  if leaveTeX
    text = putMathBack text, math
  else
    text = postprocessKaTeX text, math
  text = postprocessCoauthorLinks text
  text = postprocessLinks text
  text = postprocessAtMentions text
  sanitize text

@formatBody = (format, body, leaveTeX = false) ->
  formatEither false, format, body, leaveTeX

@formatTitle = (format, title, leaveTeX = false) ->
  formatEither true, format, title, leaveTeX

@formatBadFile = (fileId) ->
  """<i class="bad-file">&lt;unknown file with ID #{fileId}&gt;</i>"""

@formatFileDescription = (file) ->
  fileId = file
  file = findFile file unless file._id
  return formatBadFile fileId unless file?
  """<i class="odd-file"><a href="#{urlToFile file}">&lt;#{file.length}-byte #{file.contentType} file &ldquo;#{file.filename}&rdquo;&gt;</a></i>"""

@formatFile = (file) ->
  fileId = file
  file = findFile file unless file._id
  return formatBadFile fileId unless file?
  switch fileType file
    when 'image'
      """<img src="#{urlToFile file}">"""
    when 'video'
      """<video controls><source src="#{urlToFile file}" type="#{file.contentType}"></video>"""
    else  ## 'unknown'
      formatFileDescription file

@formatFilename = (msg, orUntitled = false) ->
  if msg.file
    file = findFile msg.file
    title = file?.filename
  if title
    #"<code>#{_.escape file.filename}</code>"
    _.escape title
  else if orUntitled
    untitledMessage
  else
    title

@formatTitleOrFilename = (msg, orUntitled = true, leaveTeX = false) ->
  if msg.format and msg.title and msg.title.trim().length > 0
    formatTitle msg.format, msg.title, leaveTeX
  else
    formatFilename msg, orUntitled

#@stripHTMLTags = (html) ->
#  html.replace /<[^>]*>/gm, ''

@indentLines = (text, indent) ->
  text.replace /^/gm, indent
