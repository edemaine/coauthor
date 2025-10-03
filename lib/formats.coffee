import {fileUrlPrefixPattern, messageFileUrlPrefixPattern} from './files'
import {untitledMessage} from './messages'
import {parseSearch} from './search'

katex = require 'katex'
katex.__defineMacro '\\epsilon', '\\varepsilon'

romanNumeral = require 'roman-numeral'

export availableFormats = ['markdown', 'latex', 'html']
#export mathjaxFormats = availableFormats

if Meteor.isClient
  Template.registerHelper 'formats', ->
    for format in availableFormats
      format: format
      active: if Template.currentData()?.format == format then 'active' else ''
      capitalized: capitalize format

escapeForHTML = (s) ->
  s
  .replace /&/g, '&amp;'
  .replace /</g, '&lt;'
  .replace />/g, '&gt;'

escapeForQuotedHTML = (s) ->
  escapeForHTML s
  .replace /"/g, '&quot;'

## Finds all $...$ and $$...$$ blocks, where ... properly deals with balancing
## braces (e.g. $\hbox{$x$}$) and escaped dollar signs (\$ doesn't count as $),
## and replaces them with the output of the given replacer function.
replaceMathBlocks = (text, replacer) ->
  #console.log text
  blocks = []
  re = /[{}]|\$\$?|\\(begin|end)\s*{((?:equation|eqnarray|align|alignat|gather|CD)\*?)}|(\\par(?![a-zA-Z])|\n[ \f\r\t\v]*\n\s*)|\\verb(.).*?\4|\\./g
  block = null
  startBlock = (b) ->
    block = b
    block.start = match.index
    block.contentStart = match.index + match[0].length
  endBlock = (skipThisToken) ->
    block.content = text[block.contentStart...match.index]
    delete block.contentStart  ## no longer needed
    ## Pass enclosing environment to KaTeX
    if block.environment
      ## Simulate \begin{eqnarray} with \begin{align} (close enough for now)
      block.environment = block.environment.replace /eqnarray/, 'align'
      block.content = "\\begin{#{block.environment}}#{block.content}\\end{#{block.environment}}"
    block.end = match.index
    block.end += match[0].length unless skipThisToken
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
        if match[3]  ## paragraph break
          if block? #and not block.display
            console.warn "Paragraph break within math block; auto-closing math (as LaTeX would)" if Meteor.isClient
            endBlock true  ## don't include paragraph break in math block
        else if match[1] == 'begin' and not block?
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

export inTag = (string, offset) ->
  ## Known issue: `<a title=">"` looks like a terminated tag to this code.
  ## This is why `escapeForQuotedHTML` escapes >s.
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
  '{': ''
  '}': ''
latexSymbolsRe = ///#{_.keys(latexSymbols).join '|'}///g
latexEscape = (x) ->
  x.replace /[-`'~\\$%&<>@]/g, (char) -> "&##{char.charCodeAt 0};"
latexURL = (x) ->
  x.replace /\\([_#@$%&])/g, '$1'
## Commands with letter names and no arguments, and a universal expansion.
## Includes text symbols from
## https://github.com/KaTeX/KaTeX/blob/master/src/symbols.js and
## https://github.com/KaTeX/KaTeX/blob/master/src/macros.js
latexSimpleCommands =
  bigskip: '<div style="padding-top:12pt;"></div>\n'
  medskip: '<div style="padding-top:6pt;"></div>\n'
  smallskip: '<div style="padding-top:3pt;"></div>\n'
  indent: ''    ## Irrelevant with Coauthor's formatting
  noindent: ''  ## Irrelevant with Coauthor's formatting
  thinspace: '&thinsp;' # narrow nonbreaking space
  enspace: '&ensp;'
  space: ' '
  nobreakspace: '&nbsp;'
  negthinspace: '&NegativeThinSpace;'
  negmedspace: '&NegativeMediumSpace;'
  negthickspace: '&NegativeThickSpace;'
  quad: '&emsp;'
  qquad: '&emsp;&emsp;'
  dots: '&hellip;'
  ldots: '&hellip;'
  textellipsis: '&hellip;'
  textasciitilde: '&Tilde;'  ## Avoid ~ -> \nbsp
  textasciicircum: '&Hat;'
  textbackslash: '&Backslash;'  ## Avoid \ processing
  textdollar: '&dollar;'  ## Should have already processed $s, but just in case
  textunderscore: '&lowbar;'  ## Avoid Markdown italic processing
  textbraceleft: '&lbrace;'  ## Avoid { processing in LaTeX mode
  textbraceright: '&rbrace;'  ## Avoid } processing in LaTeX mode
  lbrack: '&lbrack;'  ## Avoid Markdown link processing
  rbrack: '&rbrack;'  ## Avoid Markdown link processing
  textless: '&lt;'  ## Avoid HTML tag
  textgreater: '&gt;'  ## Avoid HTML tag
  textbar: '&vert;'  ## Avoid Markdown table processing
  textbardbl: '&parallel;'
  textendash: '&ndash;'
  textemdash: '&mdash;'
  textquoteleft: '&lsquo;'
  lq: '&lsquo;'
  textquoteright: '&rsquo;'
  rq: '&rsquo;'
  textquotedblleft: '&ldquo;'
  textquotedblright: '&rdquo;'
  aa: '&aring;'
  AA: '&Aring;'
  i: '\u0131'
  j: '\u0237'
  ss: '&szlig;'
  ae: '&aelig;'
  AE: '&AElig;'
  oe: '&oelig;'
  OE: '&OElig;'
  o: '&oslash;'
  O: '&Oslash;'
  S: '&sect;'
  P: '&para;'
  degree: '&deg;'
  textdegree: '&deg;'
  dag: '&dagger;'
  textdagger: '&dagger;'
  ddag: '&ddagger;'
  textdaggerdbl: '&ddagger;'
  checkmark: '&checkmark;'
  copyright: '&copy;'
  textcopyright: '&copy;'
  textregistered: '&reg;'
  circledR: '&reg;'
  yen: '&yen;'
  pounds: '&pound;'
  textsterling: '&pound;'
  maltese: '&maltese;'
latexSimpleCommandsRe =
  ///\\(#{(x for x of latexSimpleCommands).join '|'})(?![a-zA-Z])\s*///g

defaultFontFamily = 'Merriweather'
lightWeight = 100
mediumWeight = 400
boldWeight = 700

## Convert verbatim environment, \url, and \href commands to HTML.
## These are special (and generally must happen first) because they can have
## special LaTeX characters that should not be treated specially
## (e.g. % should not be a comment when in a URL or verbatim).
latex2htmlVerb = (text) ->
  text.replace /\\begin\s*{verbatim}([^]*?)\\end\s*{verbatim}/g,
    (match, verb) => "<pre>#{latexEscape verb}</pre>"
  .replace /\\url\s*{([^{}]*)}/g, (match, url) =>
    url = latexURL url
    """<a href="#{url}">#{latexEscape url}</a>"""
  .replace /\\href\s*{([^{}]*)}\s*{((?:[^{}]|{[^{}]*})*)}/g,
    (match, url, text) =>
      url = latexURL url
      """<a href="#{url}">#{text}</a>"""
  .replace /\\begin\s*{CJK(\*?)}\s*{UTF8}\s*{[^{}]*}(.*?)\\end{CJK\*?}/g,
    (match, star, text) =>
      text = text.replace /\s+/g, '' if star
      text

## Remove comments, stripping newlines from the input.
latexStripComments = (text) ->
  text.replace /(^|[^\\])%.*$\n?/mg, (match, prefix, offset, string) ->
    if inTag string, offset
      ## Potential unclosed HTML tag: leave alone, but process other
      ## %s on the same line after tag closes.
      close = match.indexOf '>'
      if close >= 0
        match[..close] + latexStripComments match[close+1..]
      else
        match
    else
      prefix

texAlign =
  raggedleft: 'right'
  raggedright: 'left'
  centering: 'center'

## Split string at all matches of given regular expression `re`,
## while ignoring `text` context that is nested within unescaped braces
## or HTML <tags> and &#123; character codes.
splitOutside = (text, re) ->
  re = ///[{}]|<[^<>]*>|&\#x?\d+;|(#{re.source})|\\.///g
  braces = 0
  start = 0
  parts = []
  while (match = re.exec text)?
    if match[0] == '{'
      braces++
    else if match[0] == '}'
      braces--
    else if match[1]? and braces == 0
      parts.push text[start...match.index]
      start = match.index + match[0].length
  parts.push text[start..]
  parts

colStyle =
  c: 'text-align: center;'
  l: 'text-align: left;'
  r: 'text-align: right;'
  p: 'vertical-align: top;'
  m: 'vertical-align: middle;'
  b: 'vertical-align: bottom;'

## Process all commands starting with \ followed by a letter a-z.
## This is not a valid escape sequence in Markdown, so can be safely supported
## in Markdown too.
latex2htmlCommandsAlpha = (text, math, macros) ->
  macros ?= {}
  macroCount = 0
  katexOptions = {macros, globalGroup: true, trust: true}
  text = text
  ## \verb is here instead of latex2htmlVerb so that it's processed after
  ## math blocks are extracted (as KaTeX has its own \verb support)
  .replace /\\verb(.)(.*?)\1/g,
    (match, char, verb) => "<code>#{latexEscape verb}</code>"
  ## Top-level \newcommand, \def, \let, etc. execute in KaTeX's global group
  ## so that macros are available in all math blocks of this message.
  .replace ///
    # newcommand command
    \\(newcommand | renewcommand | providecommand ) \s*
    # macro name
    (?: \\([a-zA-Z@]+|.) | \{ [^}]+ \} ) \s*
    # optional argument
    (?: \[ [^\]]* \])? \s*
    # expansion
    \{ (?:[^{}] | \{ (?:[^{}] | {[^{}]*})* \})* \}
    |
    # def command
    (?: \\(global|long|outer) \s* )? \\(def|gdef|edef|xdef) \s*
    # macro name
    \\ ([a-zA-Z@]+|.) \s*
    # arguments
    [^{}\n]*
    # expansion
    \{ (?:(?:[^{}]|{(?:[^{}]|{[^{}]*})*})*) \}
    |
    # let command
    (?: \\(global|long|outer) \s* )? \\let \s*
    \\ ([a-zA-Z@]+[ \t]*|.)
    =? \s*
    \\ ([a-zA-Z@]+[ \t]*|.)
  ///g, (match) =>
    try
      katex.renderToString match, katexOptions
      macroCount++
      ''
    catch e
      throw e unless e instanceof katex.ParseError
      #console.warn "KaTeX failed to parse $#{content}$: #{e}"
      title = escapeForQuotedHTML e.toString()
      latex = escapeForHTML match
      """<span class="katex-error" title="#{title}">#{latex}</span>"""
  ## Remove location info from macro tokens to avoid circular structure
  if macroCount
    for key, value of macros
      continue unless value.tokens?
      for token in value.tokens
        delete token.loc
  ## Expand macros at top-level text mode too. (Math is already factored out.)
  commands = Object.keys macros
  if commands.length
    r = ///
      ({?)            # allow {\macro} notation to force space after macro
      (?=\\)          # optimize and force leading backslash
      (#{commands.map(escapeRegExp).join '|'})  # command
      (?![a-zA-z@])   # ensure full-word match
      [ \t]*          # consume spaces after \macro, like TeX does, but not \n
      (?:{})?         # allow \macro{} notation to force space after macro
      (}?)            # allow {\macro} notation to force space after macro
      (?:\\(?=\s))?   # allow \macro\ notation to force space after macro
    ///g
    unexpandable = new Set  # macro offsets in text that shouldn't be expanded
    loop
      subs = 0
      delta = 0
      text = text.replace r, (match, left, command, right, offset) =>
        return match if unexpandable.has offset + left.length
        def = macros[command]
        return match unless def?
        subs++
        left = right = '' if left and right  # {\macro} -> \macro
        if def.unexpandable  # as set by \let
          unexpandable.add offset + delta + left.length
        if def.numArgs
          console.warn "Coauthor doesn't yet support macros with arguments at the top level. Use math mode."
        def = [...def.tokens]
        .reverse()
        .map (token) => token.text
        .join ''
        delta += left.length + def.length + right.length - match.length
        left + def + right
      break unless subs
  text = text
  ## Process tabular environments first in order to split cells at &
  ## (so e.g. \bf is local to the cell)
  .replace /\\begin\s*{tabular}\s*{((?:[^{}]|{(?:[^{}]|{[^{}]*})*})*)}([^]*?)\\end\s*{tabular}/g, (m, cols, body) ->
    cols = cols.replace /\|/g, '' # not yet supported
    body = body.replace /\\hline\s*|\\cline\s*{[^{}]*}/g, '' # not yet supported
    cols = cols.replace /\*\s*(\d|{\s*\d+\s*})\s*([^{}\s]|{(?:[^{}]|{[^{}]*})*})/g,
      (match, repeat, body) =>
        body = body[1...-1] if body[0] == '{'
        repeat = repeat[1...-1] if repeat.startsWith '{'
        repeat = parseInt repeat, 10
        repeat = 0 if repeat < 0
        repeat = 1000 if repeat > 1000
        body.repeat repeat
    parseAlign = (pattern) =>
      pattern = pattern[1...-1] if pattern.startsWith '{'
      align = pattern[0]
      width = pattern[1..]
      width = width[1...-1] if width.startsWith '{'
      style = ''
      if align of colStyle
        style += colStyle[align]
      if width
        style += "width: #{width};"
      style
    colStyles = []
    cols.replace /(\w)({[^{}]*})?/g, (match) => colStyles.push parseAlign match
    skip = {}
    '<table>' +
      (for row in splitOutside body, /(?:\\\\|\[DOUBLEBACKSLASH\])/ #(?:\s*\\(?:hline|cline\s*{[^{}]*}))?/
         #console.log row
         continue unless row.trim()
         colnum = 0
         "<tr>\n" +
         (for col in splitOutside row, /&/
            if skip[colnum]
              skip[colnum]--
              colnum++
              continue
            attrs = ''
            style = colStyles[colnum]
            ## "If you want to use both \multirow and \multicolumn on the same
            ## entry, you must put the \multirow inside the \multicolumn"
            ## [http://ctan.mirrors.hoobly.com/macros/latex/contrib/multirow/multirow.pdf]
            if (match = /\\multicolumn\s*(\d|{\s*\d+\s*})\s*(\w|{[^{}]*})\s*{((?:[^{}]|{(?:[^{}]|{[^{}]*})*})*)}/.exec col)?
              colspan = parseInt (match[1].replace /[{}]/g, ''), 10
              attrs += " colspan=\"#{colspan}\""
              style = parseAlign match[2]
              col = match[3]
            else
              colspan = 1
            ## In HTML, rowspan means that later rows shouldn't specify <td>s
            ## for that column, while in LaTeX, they are still present.
            if (match = /\\multirow\s*(\d|{\s*\d+\s*})\s*([\w\*]|{[^{}]*})\s*{((?:[^{}]|{(?:[^{}]|{[^{}]*})*})*)}/.exec col)?
              rowspan = parseInt (match[1].replace /[{}]/g, ''), 10
              skip[colnum] ?= 0
              skip[colnum] += rowspan - 1
              attrs += " rowspan=\"#{rowspan}\""
              style += 'vertical-align: middle;'
              if (width = match[2]) and width != '*'
                width = width[1...-1] if width.startsWith '{'
                style += "width: #{width};"
              col = match[3]
            attrs += " style=\"#{style}\"" if style
            colnum += colspan
            "<td#{attrs}>#{col}</td>\n"
         ).join('') +
         "</tr>\n"
      ).join('') +
    '</table>'
  .replace /\\(BY|YEAR)\s*{([^{}]*)}/g, '<span style="border: thin solid; margin-left: 0.5em; padding: 0px 4px; font-variant:small-caps">$2</span>'
  .replace /\\protect(?![a-zA-Z])\s*/g, ''
  .replace /\\par(?![a-zA-Z])\s*/g, '<p>'
  .replace /\\sout\s*{((?:[^{}]|{(?:[^{}]|{[^{}]*})*})*)}/g, '<s>$1</s>'
  .replace /\\emph\s*{((?:[^{}]|{(?:[^{}]|{[^{}]*})*})*)}/g, '<em>$1</em>'
  .replace /\\textit\s*{((?:[^{}]|{(?:[^{}]|{[^{}]*})*})*)}/g, '<span style="font-style: italic">$1</span>'
  .replace /\\textup\s*{((?:[^{}]|{(?:[^{}]|{[^{}]*})*})*)}/g, '<span style="font-style: normal">$1</span>'
  .replace /\\textlf\s*{((?:[^{}]|{(?:[^{}]|{[^{}]*})*})*)}/g, """<span style="font-weight: #{lightWeight}">$1</span>"""
  .replace /\\textmd\s*{((?:[^{}]|{(?:[^{}]|{[^{}]*})*})*)}/g, """<span style="font-weight: #{mediumWeight}">$1</span>"""
  .replace /\\textbf\s*{((?:[^{}]|{(?:[^{}]|{[^{}]*})*})*)}/g, """<span style="font-weight: #{boldWeight}">$1</span>"""
  .replace /\\(textrm|textnormal)\s*{((?:[^{}]|{[^{}]*})*)}/g, """<span style="font-family: #{defaultFontFamily}">$2</span>"""
  .replace /\\textsf\s*{((?:[^{}]|{(?:[^{}]|{[^{}]*})*})*)}/g, '<span style="font-family: sans-serif">$1</span>'
  #.replace /\\texttt\s*{((?:[^{}]|{(?:[^{}]|{[^{}]*})*})*)}/g, '<span style="font-family: monospace">$1</span>'
  .replace /\\texttt\s*{((?:[^{}]|{(?:[^{}]|{[^{}]*})*})*)}/g, (match, inner) ->
    inner = inner.replace /-/g, '&hyphen;'  ## prevent -- coallescing
    """<span style="font-family: monospace">#{inner}</span>"""
  .replace /\\textsc\s*{((?:[^{}]|{(?:[^{}]|{[^{}]*})*})*)}/g, '<span style="font-variant: small-caps">$1</span>'
  .replace /\\textsl\s*{((?:[^{}]|{(?:[^{}]|{[^{}]*})*})*)}/g, '<i class="slant">$1</i>'
  loop ## Repeat until done to support overlapping matches, e.g. \rm x \it y
    old = text
    text = text
    .replace /\\em(?![a-zA-Z])\s*((?:[^{}<>]|{[^{}]*})*)/g, '<em>$1</em>'
    .replace /\\itshape(?![a-zA-Z])\s*((?:[^{}<>]|{[^{}]*})*)/g, '<span style="font-style: italic">$1</span>'
    .replace /\\upshape(?![a-zA-Z])\s*((?:[^{}<>]|{[^{}]*})*)/g, '<span style="font-style: normal">$1</span>'
    .replace /\\lfseries(?![a-zA-Z])\s*((?:[^{}<>]|{[^{}]*})*)/g, """<span style="font-weight: #{lightWeight}">$1</span>"""
    .replace /\\mdseries(?![a-zA-Z])\s*((?:[^{}<>]|{[^{}]*})*)/g, """<span style="font-weight: #{mediumWeight}">$1</span>"""
    .replace /\\bfseries(?![a-zA-Z])\s*((?:[^{}<>]|{[^{}]*})*)/g, """<span style="font-weight: #{boldWeight}">$1</span>"""
    .replace /\\rmfamily(?![a-zA-Z])\s*((?:[^{}<>]|{[^{}]*})*)/g, """<span style="font-family: #{defaultFontFamily}">$1</span>"""
    .replace /\\sffamily(?![a-zA-Z])\s*((?:[^{}<>]|{[^{}]*})*)/g, '<span style="font-family: sans-serif">$1</span>'
    .replace /\\ttfamily(?![a-zA-Z])\s*((?:[^{}<>]|{[^{}]*})*)/g, '<span style="font-family: monospace">$1</span>'
    .replace /\\scshape(?![a-zA-Z])\s*((?:[^{}<>]|{[^{}]*})*)/g, '<span style="font-variant: small-caps">$1</span>'
    .replace /\\slshape(?![a-zA-Z])\s*((?:[^{}<>]|{[^{}]*})*)/g, '<span style="font-style: oblique">$1</span>'
    ## Font size commands.  Bootstrap defines base font-size as 14px.
    ## We multiply this by a scale factor defined by LaTeX's 10pt sizing chart
    ## [https://en.wikibooks.org/wiki/LaTeX/Fonts].
    .replace /\\tiny(?![a-zA-Z])\s*((?:[^{}<>]|{[^{}]*})*)/g, '<span style="font-size: 7px">$1</span>'
    .replace /\\scriptsize(?![a-zA-Z])\s*((?:[^{}<>]|{[^{}]*})*)/g, '<span style="font-size: 9.8px">$1</span>'
    .replace /\\footnotesize(?![a-zA-Z])\s*((?:[^{}<>]|{[^{}]*})*)/g, '<span style="font-size: 11.2px">$1</span>'
    .replace /\\small(?![a-zA-Z])\s*((?:[^{}<>]|{[^{}]*})*)/g, '<span style="font-size: 12.6px">$1</span>'
    .replace /\\large(?![a-zA-Z])\s*((?:[^{}<>]|{[^{}]*})*)/g, '<span style="font-size: 16.8px">$1</span>'
    .replace /\\Large(?![a-zA-Z])\s*((?:[^{}<>]|{[^{}]*})*)/g, '<span style="font-size: 20.2px">$1</span>'
    .replace /\\LARGE(?![a-zA-Z])\s*((?:[^{}<>]|{[^{}]*})*)/g, '<span style="font-size: 24.2px">$1</span>'
    .replace /\\huge(?![a-zA-Z])\s*((?:[^{}<>]|{[^{}]*})*)/g, '<span style="font-size: 29px">$1</span>'
    .replace /\\Huge(?![a-zA-Z])\s*((?:[^{}<>]|{[^{}]*})*)/g, '<span style="font-size: 34.8px">$1</span>'
    ## Resetting font commands
    .replace /\\(?:rm|normalfont)(?![a-zA-Z])\s*((?:[^{}<>]|{[^{}]*})*)/g, """<span style="font-family: #{defaultFontFamily}; font-style: normal; font-weight: normal; font-variant: normal">$1</span>"""
    .replace /\\md(?![a-zA-Z])\s*((?:[^{}<>]|{[^{}]*})*)/g, """<span style="font: #{defaultFontFamily}; font-weight: #{mediumWeight}">$1</span>"""
    .replace /\\bf(?![a-zA-Z])\s*((?:[^{}<>]|{[^{}]*})*)/g, """<span style="font: #{defaultFontFamily}; font-weight: #{boldWeight}">$1</span>"""
    .replace /\\it(?![a-zA-Z])\s*((?:[^{}<>]|{[^{}]*})*)/g, """<span style="font: #{defaultFontFamily}; font-style: italic">$1</span>"""
    .replace /\\sl(?![a-zA-Z])\s*((?:[^{}<>]|{[^{}]*})*)/g, """<span style="font: #{defaultFontFamily}; font-style: oblique">$1</span>"""
    .replace /\\sf(?![a-zA-Z])\s*((?:[^{}<>]|{[^{}]*})*)/g, """<span style="font: #{defaultFontFamily}; font-family: sans-serif">$1</span>"""
    .replace /\\tt(?![a-zA-Z])\s*((?:[^{}<>]|{[^{}]*})*)/g, """<span style="font: #{defaultFontFamily}; font-family: monospace">$1</span>"""
    .replace /\\sc(?![a-zA-Z])\s*((?:[^{}<>]|{[^{}]*})*)/g, """<span style="font: #{defaultFontFamily}; font-variant: small-caps">$1</span>"""
    ## Alignment
    .replace /\\(raggedleft|raggedright|centering)(?![a-zA-Z])\s*((?:[^{}]|{(?:[^{}]|{[^{}]*})*})*)/g, (match, align, content) ->
      """<div style="text-align:#{texAlign[align]};"><p>#{content}</p></div>"""
    break if old == text
  listStyles = []
  listCounts = []
  text = text
  .replace /\\(uppercase|MakeTextUppercase)\s*{((?:[^{}]|{(?:[^{}]|{[^{}]*})*})*)}/g, '<span style="text-transform: uppercase">$2</span>'
  .replace /\\(lowercase|MakeTextLowercase)\s*{((?:[^{}]|{(?:[^{}]|{[^{}]*})*})*)}/g, '<span style="text-transform: lowercase">$2</span>'
  .replace /\\underline\s*{((?:[^{}]|{(?:[^{}]|{[^{}]*})*})*)}/g, '<u>$1</u>'
  .replace /\\textcolor\s*{((?:[^{}]|{(?:[^{}]|{[^{}]*})*})*)}\s*{((?:[^{}]|{(?:[^{}]|{[^{}]*})*})*)}/g, '<span style="color: $1">$2</span>'
  .replace /\\colorbox\s*{((?:[^{}]|{(?:[^{}]|{[^{}]*})*})*)}\s*{((?:[^{}]|{(?:[^{}]|{[^{}]*})*})*)}/g, '<span style="background-color: $1">$2</span>'
  ## Nested list environments: process all together (with listStyles global)
  ## to handle special \item formatting.
  .replace ///((?:\s|<p>)*)(?:
    \\begin\s*{(itemize)}
   |\\begin\s*{enumerate}(?:\s*\[((?:[^\[\]]|{[^{}]*})*)\])?
   |\\end\s*{(itemize|enumerate)}
   |\\item(?![a-zA-Z])\s*(?:\[([^\[\]]*)\]\s*)?
  )///g, (match, space, beginItemize, enumArg, end, itemArg) ->
    space.replace(/\n\s*\n|<p>/g, '\n') +  ## eat paragraphs
    switch match[space.length + 1]
      when 'b' ## \begin
        listStyles.push enumArg
        listCounts.push 0
        if beginItemize
          '<ul>'
        else # beginEnumerate
          '<ol>'
      when 'e' ## \end
        listStyles.pop()
        listCounts.pop()
        if end == 'itemize'
          '</ul>'
        else
          '</ol>'
      when 'i' ## \item
        listCounts[listCounts.length-1]++
        if listStyles[listStyles.length-1]?
          count = listCounts[listCounts.length-1]
          itemArg ?= listStyles[listStyles.length-1]
          .replace /[AaIi1]|{[^{}]*}/g, (match) ->
            switch match
              when '1'
                count
              when 'a', 'A'
                String.fromCharCode (match.charCodeAt() + count - 1)
              when 'i'
                (romanNumeral.convert count).toLowerCase()
              when 'I'
                romanNumeral.convert count
              else ## {...}
                match[1...-1]
        if itemArg?
          ## Data didn't support e.g. math: """<li data-itemlab="#{arg}">"""
          """<li class="noitemlab"><span class="itemlab">#{itemArg}</span>"""
        else
          '<li>'
  ## Because we define styles for first <p> child of <li>, we need to make
  ## sure that, if an <li> has any <p> in it, then it also starts with one.
  .replace /(<li\b[^<>]*>)([^]*?)<p\b[^<>]*>/gi, (match, li, inner) ->
    unless inner.match /<li\b|<\/\s*[uo]l\b/i
      li + '<p>' + match[li.length..]
    else
      match
  .replace /\\chapter\s*\*?\s*{((?:[^{}]|{(?:[^{}]|{[^{}]*})*})*)}/g, '<h1>$1</h1><p>'
  .replace /\\section\s*\*?\s*{((?:[^{}]|{(?:[^{}]|{[^{}]*})*})*)}/g, '<h2>$1</h2><p>'
  .replace /\\subsection\s*\*?\s*{((?:[^{}]|{(?:[^{}]|{[^{}]*})*})*)}/g, '<h3>$1</h3><p>'
  .replace /\\subsubsection\s*\*?\s*{((?:[^{}]|{(?:[^{}]|{[^{}]*})*})*)}/g, '<h4>$1</h4><p>'
  .replace /\\paragraph\s*\*?\s*{((?:[^{}]|{(?:[^{}]|{[^{}]*})*})*)}\s*/g, '<p><b>$1</b> '
  .replace /\\footnote\s*{((?:[^{}]|{(?:[^{}]|{[^{}]*})*})*)}/g, '[$1]'
  .replace /\\includegraphics\s*(\[[^\[\]]*\]\s*)?{((?:[^{}]|{(?:[^{}]|{[^{}]*})*})*)}/g,
    (match, optional = '', graphic) ->
      style = ''
      optional.replace /width\s*=\s*([-0-9.]+)\s*(%|[a-zA-Z]*)/g,
        (match2, value, unit) ->
          style += "width: #{value}#{unit};"
          ''
      .replace /height\s*=\s*([-0-9.]+)\s*(%|[a-zA-Z]*)/g,
        (match2, value, unit) ->
          style += "height: #{value}#{unit};"
          ''
      .replace /scale\s*=\s*([-0-9.]+)/g,
        (match2, value, unit) ->
          style += "width: #{100 * parseFloat value}%;"
          ''
      style = ' style="' + style + '"' if style
      """<img src="#{graphic}"#{style}>"""
  .replace /\\pdftooltip\s*{((?:[^{}]|{(?:[^{}]|{[^{}]*})*})*)}\s*{((?:[^{}]|{(?:[^{}]|{[^{}]*})*})*)}/g,
    (match, p1, p2) -> """<span title="#{(putMathBack p2, math).replace /"/g, '&#34;'}">#{p1}</span>"""
  .replace /\\raisebox\s*{\s*([-0-9.]+)\s*([a-zA-Z]*)\s*}{((?:[^{}]|{(?:[^{}]|{[^{}]*})*})*)}/g,
    (match, value, unit, arg) ->
      if value[0] == '-'
        value = value[1..]
      else
        value = "-#{value}"
      """<span style="margin-top: #{value}#{unit};">#{arg}</span>"""
  .replace /\\begin\s*{(details|\+)}(\s*\[((?:[^\]{}]|{(?:[^{}]|{[^{}]*})})*)\])?/g,
    (m, env, x, opt) ->
      '<details>' + if opt then "<summary>#{opt}</summary>" else ''
  .replace /\\end\s*{(details|\+)}/g, '</details>'
  .replace /(\\begin\s*{([^{}]+))\+}(\s*\[((?:[^\]{}]|{(?:[^{}]|{[^{}]*})})*)\])?/g,
    (m, prefix, env, rest, opt) ->
      """<details>
      <summary>#{capitalize env}#{if opt then " (#{opt})" else ''}</summary>
      #{prefix}}#{rest ? ''}
      """
  .replace /(\\end\s*{[^{}]+)\+}/g, "$1}</details>"
  .replace /\\begin\s*{(problem|question|idea|theorem|conjecture|lemma|corollary|fact|observation|proposition|claim|definition|example|remark|note|hint)([^{}]*)}(\s*\[([^\]]*)\])?/g, (m, env, rest, x, opt) -> """<blockquote#{if /^(example|remark|note|hint)/.test env then '' else ' class="thm"'}><p><b>#{capitalize env}#{rest}#{if opt then " (#{opt})" else ''}:</b> """
  .replace /\\end\s*{(problem|question|idea|theorem|conjecture|lemma|corollary|fact|observation|proposition|claim|definition|example|remark|note|hint)([^{}]*)}/g, '</blockquote>'
  .replace /\\begin\s*{(quote)}/g, '<blockquote><p>'
  .replace /\\end\s*{(quote)}/g, '</blockquote>'
  .replace /\\begin\s*{(proof|pf)([^{}]*)}(\s*\[((?:[^\]{}]|{(?:[^{}]|{[^{}]*})})*)\])?/g, (m, env, rest, x, opt) -> "<b>Proof#{rest}#{if opt then " (#{opt})" else ''}:</b> "
  .replace /\\end\s*{(proof|pf)([^{}]*)}/g, ' <span class="pull-right">&#8718;</span></p><p class="clearfix">'
  .replace /\\begin\s*{center}/g, '<div class="center">'
  .replace /\\end\s*{center}/g, '</div>'
  .replace latexSimpleCommandsRe, (match, name) -> latexSimpleCommands[name]
  ## The following tweaks are not LaTeX actually, but useful in all modes,
  ## so we do them here.
  .replace /\b[0-9]+(x[0-9]+)+\b/ig, (match) ->
     match.replace /x/ig, '\u00a0×\u00a0'
  {text, macros}

## "Light" LaTeX support, using only commands that start with a letter a-z,
## so are safe to process in Markdown.  No accent support.
latex2htmlLight = (text, me, macros) ->
  text = latex2htmlVerb text
  ## After \def expansion and verbatim processing, protect math
  {text, math} = preprocessKaTeX text
  ## After math extraction, process @mentions
  text = processAtMentions text, me
  {text, macros} = latex2htmlCommandsAlpha text, math, macros
  {text, math, macros}

## Full LaTeX support, including all supported commands and symbols
## (% make comments, ~ makes nonbreaking space, etc.).
latex2html = (text, me, macros) ->
  text = latex2htmlVerb text
  text = latexStripComments text
  ## Paragraph detection must go before any macro expansion (which eat \n's)
  text = text.replace /\n\n+/g, '\n\\par\n'
  ## After \def expansion and verbatim processing, protect math
  {text, math} = preprocessKaTeX text
  ## After math extraction, process @mentions
  text = processAtMentions text, me
  ## Start initial paragraph
  text = '<p>' + text
  ## Commands
  text = text.replace /\\\\/g, '[DOUBLEBACKSLASH]'
  {text, macros} = latex2htmlCommandsAlpha text, math, macros
  text = text
  .replace /\\c\s*{s}/g, '&#351;'
  .replace /\\c\s*{z}/g, 'z&#807;'
  .replace /\\v\s*{C}/g, '&#268;'
  .replace /\\v\s*{s}/g, '&#353;'
  .replace /\\v\s*{n}/g, '&#328;'
  .replace /\\v\s*{r}/g, '&#345;'
  .replace /\\u\s*{a}/g, '&#259;'
  .replace /\\v\s*{a}/g, '&#462;'
  .replace /\\H\s*{o}/g, '&#337;'
  .replace /\\"{(.)}/g, '&$1uml;'
  .replace /\\"(.)/g, '&$1uml;'
  .replace /\\'c|\\'{c}/g, '&#263;'
  .replace /\\'n|\\'{n}/g, '&#324;'
  .replace /\\'{(.)}/g, '&$1acute;'
  .replace /\\'(.)/g, '&$1acute;'
  .replace /\\`{(.)}/g, '&$1grave;'
  .replace /\\`(.)/g, '&$1grave;'
  .replace /\\\^{(.)}/g, '&$1circ;'
  .replace /\\\^{}/g, '&Hat;'
  .replace /\\\^(.)/g, '&$1circ;'
  .replace /\\~{(.)}/g, '&$1tilde;'
  .replace /\\~{}/g, '&tilde;'
  .replace /\\~(.)/g, '&$1tilde;'
  .replace /\\=a|\\={a}/g, '&#257;'
  .replace /\\=e|\\={e}/g, '&#275;'
  .replace /\\=g|\\={g}/g, '&#7713;'
  .replace /\\=i|\\={i}|\\=\\i\s*|\\={\\i}/g, '&#299;'
  .replace /\\=o|\\={o}/g, '&#333;'
  .replace /\\=u|\\={u}/g, '&#363;'
  .replace /\\=y|\\={y}/g, '&#563;'
  .replace /\\,/g, '&#8239;' # narrow nonbreaking space
  .replace /\\&/g, '&amp;'
  .replace /\\([${}%#])/g, '$1'
  .replace /\\\s+/g, ' '
  .replace latexSymbolsRe, (match, offset, string) ->
    if inTag string, offset  ## potential unclosed HTML tag; leave alone
      match
    else
      latexSymbols[match]
  .replace /<p>\s*(<h[1-9]>)/g, '$1'
  .replace /<p>(\s*<p>)+/g, '<p>'  ## Remove double paragraph breaks
  .replace /\[DOUBLEBACKSLASH\]/g, '<br>'
  {text, math, macros}

formats =
  markdown: (text, title, me, macros) ->
    ## Escape all characters that can be (in particular, _s) that appear
    ## inside math mode, to prevent Marked from processing them.
    ## The Regex is exactly marked.js's inline.escape.
    #text = replaceMathBlocks text, (block) ->
    #  block.replace /[\\`*{}\[\]()#+\-.!_]/g, '\\$&'
    #marked.Lexer.rules = {text: /^[^\n]+/} if title
    ## First extract Markdown verbatim environments (backticks) to prevent
    ## LaTeX processing on them (especially math mode, so $ is inert in code).
    {text, ticks} = preprocessMarkdownTicks text
    ## Support what we can of LaTeX before doing Markdown conversion.
    {text, math, macros} = latex2htmlLight text, me, macros
    #console.log text, math
    ## Put Markdown verbatims back in.
    text = putTicksBack text, ticks
    if title  ## use "single-line" version of Markdown
      text = markdownInline text
    else
      text = markdown text
    #console.log 'markdown', text
    ## Convert <ol start=...> output from Markdown to CSS-compatible reset.
    text = text.replace /<ol start="([\d+])">/ig, (match, start) ->
      """<ol style="counter-reset: enum #{-1 + parseInt start}">"""
    ## Wrap markdown-it-task-checkbox checkboxes in <span class="itemlab">,
    ## remove the <label> applied to the item's first paragraph, and
    ## (until checking is supported) replace checkbox with Unicode symbol.
    text = text.replace ///
      (<li\b[^<>]*>\s*)
      (<p>\s*)?
      (<input\b[^<>]*>) \s*
      (<label[^<>]*>\s*(.*?)</label>)?
    ///ig,
      (match, li, p, input, label, labelInner) ->
        if /type\s*=\s*"checkbox"/.test input
          if /checked/.test input
            #input = '<span class="fake-checkbox">\u{1f5f9}</span>'
            #input = '<span class="fake-checkbox">\u2611</span>'
            input = '<span class="fas fa-check-square"></span>'
          else
            #input = '<span class="fake-checkbox">\u2610</span>'
            input = '<span class="far fa-square"></span>'
          "#{li}<span class=\"itemlab\">#{input}</span>#{p ? ''}#{labelInner ? ''}"
        else
          match
    #.replace /(<label\b[^<>]*>)\s*/ig, '$1'
    {text, math, macros}
  latex: (text, title, me, macros) ->
    latex2html text, me, macros
  html: (text, title, macros) ->
    linkify text

export coauthorLinkPrefixRe = "coauthor:/?/?"
export coauthorLinkBodyRe = "([a-zA-Z0-9]+)"
export coauthorLinkBodyHashRe = "#{coauthorLinkBodyRe}(#[a-zA-Z0-9]*)?"
export coauthorLinkRe = "#{coauthorLinkPrefixRe}#{coauthorLinkBodyRe}"
export coauthorLinkHashRe = "#{coauthorLinkPrefixRe}#{coauthorLinkBodyHashRe}"
coauthorEitherLinkRe = coauthorEitherLinkHashRe = null

export initLinkRes = ->
  return if coauthorEitherLinkRe?
  coauthorEitherLinkPrefixRe = "(?:#{coauthorLinkPrefixRe}|#{urlFor 'message',
    group: '.*'
    message: ''
    0: '*'
    1: '*'
  .replace /\./g, '[^/#]'
  }/)"
  coauthorEitherLinkRe = "#{coauthorEitherLinkPrefixRe}#{coauthorLinkBodyRe}"
  coauthorEitherLinkHashRe = "#{coauthorEitherLinkPrefixRe}#{coauthorLinkBodyHashRe}"

export parseCoauthorMessageUrl = (url, simplify) ->
  match = new RegExp("^#{urlFor 'message',
    group: '(.*)'
    message: '(.*)'
    0: '*'
    1: '*'
  .replace /\./g, '[^/#]'
  }(#.*)?$").exec url
  if match?
    match =
      group: match[1]
      message: match[2]
      hash: match[3] ? ''
    if simplify and match.hash[1..] == match.message
      match.hash = ''
    match

export parseCoauthorAuthorUrl = (url) ->
  match = new RegExp("^#{urlFor 'author',
    group: '(.*)'
    author: '(.*)'
    0: '*'
    1: '*'
  }$").exec url
  if match?
    group: match[1]
    author: match[2]

export parseCoauthorMessageFileUrl = (url) ->
  match = ///^#{messageFileUrlPrefixPattern}(.*)$///.exec url
  return unless match?
  message: match[1]

imageTitleAndWarning = (fileMsg, containerMsg) ->
  ## xxx Should we subscribe to the linked message when we can't find it?
  fileMsg = findMessage fileMsg
  attrs = prefix = ''
  return {attrs, prefix} unless fileMsg?
  # Only look up container message if we need it (e.g. file is deleted)
  container = => containerMsg = findMessage containerMsg
  title = titleOrFilename(fileMsg) ? ''
  classes = []
  classes.push 'deleted' if fileMsg.deleted and not container().deleted
  classes.push 'unpublished' if not fileMsg.published and container().published
  classes.push 'private' if fileMsg.private and not container().private
  if classes.length
    attrs += """class="#{classes.join ' '}" """
    warning = "WARNING: Image is #{classes.join(' and ').toUpperCase()} so will NOT BE VISIBLE to most users!"
    prefix = """<div class="warning #{classes.join ' '}">#{warning.replace /[A-Z]{2,}/g, "<b>$&</b>"}</div>"""
    title = "#{warning} #{title}"
  attrs += """title="#{escapeForQuotedHTML title}" """ if title
  {attrs, prefix}

postprocessCoauthorLinks = (text, msgId) ->
  initLinkRes()
  text
  .replace ///(<img\s[^<>]*src\s*=\s*['"])#{coauthorLinkRe}///ig,
    (match, img, id) ->
      img + urlToFile id
  .replace ///(<a\s[^<>]*)(href\s*=\s*['"])#{coauthorEitherLinkHashRe}((['"]>)#{coauthorEitherLinkRe}(</a>))?///ig,
    (match, a, href, id, hash, suffix, suffixLeft, suffixId, suffixRight) ->
      ## xxx Should we subscribe to the linked message when we can't find it?
      ## (This would just be to get its title, so maybe not worth it.)
      msg = findMessage id
      title = titleOrFilename msg
      url = urlFor('message',
        group: msg?.group or wildGroup
        message: id
      )
      url += hash if hash?
      if title
        a += """title="#{escapeForQuotedHTML title}" """
        if suffixId == id
          #a += """class="coauthor-link" """
          text = formatTitle msg.format, title, id: msg._id
          if msgId? and findMessage(msgId)?.group != msg.group
            text = "[#{escapeForHTML msg.group}] #{text}"
          #suffix = """#{suffixLeft}<img src="#{Meteor.absoluteUrl 'favicon32.png'}" class="natural">#{text}#{suffixRight}"""
          suffix = """#{suffixLeft}#{text}#{suffixRight}"""
      suffix ?= ''
      a + href + url + suffix
  .replace ///(<img\s[^<>]*)(src\s*=\s*['"])(#{fileUrlPrefixPattern}[^'"]*)(['"][^<>]*>)///ig,
    (match, img, src, url, isFile, isInternalFile, suffix) ->
      ## xxx Should we subscribe to the linked message when we can't find it?
      if isFile
        fileMsg = findMessage url2file url
        return match unless fileMsg?
        {attrs, prefix} = imageTitleAndWarning fileMsg, msgId
        fileId = fileMsg.file
      else # if isInternalFile
        fileId = url2internalFile url
        attrs = prefix = ''
      file = findFile fileId
      return match unless file?
      prefix +
      switch fileType file
        when 'video'
          formatVideo file, url, attrs
        when 'pdf'
          if Meteor.isServer
            """<div>[PDF file &ldquo;<a href="#{url}">#{file.filename}</a>&rdquo;]</div>"""
          else
            """<div #{attrs}data-messagepdf="#{fileId}"></div>"""
        else
          img + attrs + src + url + suffix

## URL regular expression with scheme:// required, to avoid extraneous matching
export urlRe = /\w+:\/\/[-\w~!$&'()*+,;=.:@%#?\/]+/g

postprocessLinks = (text) ->
  text.replace urlRe, (match, offset, string) ->
    #console.log string, offset, inTag string, offset
    if inTag string, offset
      match
    else
      match.replace /\/+/g, (slash) ->
        "#{slash}<wbr>"  ## Allow linebreak after every slash group

@allUsernames = ->
  Meteor.users.find {}, fields: username: 1
  .map (user) -> user.username

## U+FF20 is FULLWIDTH COMMERCIAL AT common in Asian scripts.
atRePrefix = '[@\uff20]'

@atRe = (users = allUsernames()) ->
  users = [users] unless _.isArray users
  ## Reverse-sort by length to ensure maximum-length match
  ## (to handle when one username is a prefix of another).
  users = _.sortBy users, (name) -> -name.length
  users = for user in users
    user = user.username if user.username?
    escapeRegExp user
  ///#{atRePrefix}(#{users.join '|'})(?!\w)///g

processAtMentions = (text, me) ->
  return text unless ///#{atRePrefix}///.test text
  users = allUsernames()
  return text unless 0 < users.length
  text.replace (atRe users), (match, user, offset, string) ->
    ## Allow escaping of @ by preceding backslash.
    unless string[offset-1] == '\\' or inTag string, offset
      "@#{linkToAuthor (routeGroup?() ? wildGroup), user, {me}}"
    else # e.g. in <a title="..."> caused by postprocessCoauthorLinks
      match

preprocessKaTeX = (text) ->
  text = text
  .replace /(\\begin\s*{(?:equation|eqnarray|align|alignat|gather|CD)\*?)\+}/g,
    """<details>
    <summary>Equation</summary>
    $1}
    """
  .replace /(\\end\s*{(?:equation|eqnarray|align|alignat|gather|CD)\*?)\+}/g,
    "$1}</details>"
  math = []
  i = 0
  text = replaceMathBlocks text, (block) ->
    math.push block
    "!MATH#{i++}ENDMATH!"  # surround with `!` to prevent linkify implicit links
  {text, math}

putMathBack = (text, math) ->
  ## Restore math
  text.replace /!MATH(\d+)ENDMATH!/g, (match, id) -> _.escape math[id].all

postprocessKaTeX = (text, math, initialBold, macros = {}) ->
  return text unless math.length
  macros = {...macros}  ## shared across multiple math expressions within same body
  if initialBold
    weights = [boldWeight]
  else
    weights = [mediumWeight]
  text.replace ///
    (['"(\[{]*)         # left puncutation to pull into math mode
    !MATH(\d+)ENDMATH!
    ([,.!?:;'"\-)\]}]*) # right puncutation to pull into math mode
    (?! -?> ) # prevent accidentally grabbing some of --> (end of HTML comment)
    (?! MATH ) # prevent accidentally grabbing part of !MATH
    | ## Detect math within bold mode:
    <span([^<>]*)> |
    <b\b |
    <strong\b |
    <\/\s*(b|strong|span)\s*>
  ///g, (match, leftPunct, id, rightPunct, spanArgs) ->
    unless id?
      if spanArgs?
        spanArgs = /style\s*=\s*['"]font-weight:\s*(\d+)/i.exec spanArgs
        if spanArgs?
          weights.push parseInt spanArgs[1]
      else if match == '<b' or match == '<strong'
        weights.push boldWeight
      else if match[...2] == '</'
        weights.pop()
      return match
    ## !MATH...ENDMATH!
    block = math[id]
    content = block.content
    #.replace /&lt;/g, '<'
    #.replace /&gt;/g, '>'
    #.replace /’/g, "'"
    #.replace /‘/g, "`"  ## remove bad Marked automatic behavior
    bold = (weights[weights.length-1] == boldWeight)
    if bold
      content = "\\boldsymbol{#{content}}"
    try
      out = katex.renderToString content,
        displayMode: block.display
        throwOnError: false
        trust: true
        macros: macros
    catch e
      throw e unless e instanceof katex.ParseError
      #console.warn "KaTeX failed to parse $#{content}$: #{e}"
      title = escapeForQuotedHTML e.toString()
      latex = escapeForHTML content
      out = """<span class="katex-error" title="#{title}">#{latex}</span>"""
    ## Remove \boldsymbol{...} from TeX source, in particular for copy/paste
    if bold
      out = out.replace /(<annotation encoding="application\/x-tex">)\\boldsymbol{([^]*?)}(<\/annotation>)/i, '$1$2$3'
    if leftPunct
      if block.display or not out.includes '<span class="base">'
        out = leftPunct + out
      else
        ## Push left punctuation inside the first base element
        ## (<span class="katex"><span class="katex-html"><span class="base">)
        ## which prevents it from being separated, while still allowing KaTeX
        ## to do its automatic line breaking.
        out = out.replace '<span class="base">', (match) ->
          """#{match}<span class="nonmath">#{leftPunct}</span>"""
    if rightPunct
      if block.display
        out += rightPunct
      else
        ## Push right punctuation inside the final base element
        ## (<span class="katex"><span class="katex-html"><span class="base">)
        ## which prevents it from being separated, while still allowing KaTeX
        ## to do its automatic line breaking.
        out = out.replace ///(</span></span></span>)?$///, (match) ->
          """<span class="nonmath">#{rightPunct}</span>#{match}"""
    out

preprocessMarkdownTicks = (text) ->
  ticks = []
  i = 0
  ## See https://spec.commonmark.org/0.29/#code-spans and
  ## https://spec.commonmark.org/0.29/#fenced-code-blocks for relevant specs.
  ## Bad cases not handled by this regex:
  ## * `foo followed by two newlines is treated as still opening a code span
  ## * <a href="`"> is treated as opening a code span
  ## * ~~~code block~~~ ignored
  ## * Indented blocks ignored
  text = text.replace ///
    (^|[^\\`])  # backticks shouldn't be preceded by \escape or more backticks
    (`+)        # one or more backticks to open
    ([^`] |         # case 1: single nontick character inside
     [^`][^]*?[^`]) # case 2: multiple characters inside, not bounded by ticks
    (\2|$)      # matching number of backticks to close
    (?!`)       # not any additional `s afterward
  ///g, (match, pre, left, mid, right) ->
    ## Three or more backticks (fenced code blocks) are terminated by end of doc
    return match unless right or left.length >= 3
    ticks.push match[pre.length..]
    "#{pre}TICK#{i++}ENDTICK"
  {text, ticks}

putTicksBack = (text, ticks) ->
  return text unless ticks.length
  text.replace /TICK(\d+)ENDTICK/g, (match, id) -> ticks[id]

## Search highlighting
formatSearchHighlight = (isTitle, text) ->
  if Meteor.isClient and Router.current()?.route?.getName() == 'search' and
     (search = Router.current()?.params?.search)?
    recurse = (query) ->
      if (query.title and isTitle) or (query.body and not isTitle)
        pattern = query.title ? query.body
        unless pattern.$not
          pattern = new RegExp pattern, 'g' if pattern instanceof RegExp
          text = text.replace pattern, (match, ...args, offset, string, grps) ->
            return match if inTag string, offset
            """<span class="highlight">#{match}</span>"""
      for list in [query.$and, query.$or]
        continue unless list
        for part in list
          recurse part
      null
    recurse parseSearch search
  text

linkToSpecificMessageRegexp = new RegExp "^#{idRegex}(_|$)"

formatEither = (isTitle, format, text, options) ->
  return text unless text?
  {leaveTeX, bold, me, id, macros} = options if options?

  ## Markdown format is special because it processes @mentions
  ## at a specific time (after verbatim extraction).

  ## LaTeX and Markdown formats are special because they do their own math
  ## and @mention preprocessing at a specific time during its formatting.
  ## Other formats (currently just HTML) don't touch math,
  ## so we need to preprocess here.
  if format in ['latex', 'markdown']
    {text, math, macros} = formats[format] text, isTitle, me, macros
  else
    {text, math} = preprocessKaTeX text
    text = processAtMentions text, me
    if format of formats
      text = formats[format] text, isTitle
    else
      console.warn "Unrecognized format '#{format}'"
    macros = {}

  ## Remove space after <li> to prevent shifting the next item right relative
  ## to the item label.  Related to CSS rule for "li > p:first-child".
  text = text.replace /(<li[^<>]*>)\s+/ig, '$1'

  ## Add missing <summary>s to <details> tags, for better formatting.
  text = text.replace /(<details[^<>]*>)([^]*?<\/details>)/ig,
    (match, head, body) ->
      unless /<summary/i.test body
        body = '<summary>Details</summary>' + body
      head + body

  ## Remove surrounding <P> block caused by Markdown and LaTeX formatters.
  if isTitle
    text = text
    .replace /^\s*<p>\s*/i, ''
    .replace /\s*<\/p>\s*$/i, ''
  if leaveTeX
    text = putMathBack text, math
  else
    text = postprocessKaTeX text, math, bold, macros
  text = linkify text  ## Extra support for links, unliked LaTeX
  text = postprocessCoauthorLinks text, id
  text = postprocessLinks text
  text = formatSearchHighlight isTitle, text
  text = sanitize text
  # After sanitization, attribute keys should be lower case and
  # attribute values should be surrounded by double quotes.
  if id?
    text = text
    .replace /\bid="MESSAGE_([^"]*)"/g, (match, subId, offset, string) ->
      return match unless inTag string, offset
      "id=\"#{id}_#{subId}\""
    .replace /\bhref="#([^"]*)"/g, (match, hash, offset, string) ->
      return match unless inTag string, offset
      return if linkToSpecificMessageRegexp.test hash
      "href=\"##{id}_#{hash}\""
  {text, macros}

formatEitherSafe = (isTitle, format, text, options) ->
  try
    formatEither isTitle, format, text, options
  catch e
    console.error e.stack ? e.toString()
    if isTitle
      {text: """
        <span class="label label-danger">Formatting error (bug in Coauthor)</span>
        <code>#{_.escape text}</code>
      """}
    else
      {text: """
        <div class="alert alert-danger">Formatting error (bug in Coauthor): #{e.toString()}</div>
        <pre>#{_.escape text}</pre>
      """}

export formatBody = (format, body, options) ->
  formatEitherSafe false, format, body, options
  # returns {text, macros}

export formatTitle = (format, title, options) ->
  formatEitherSafe true, format, title, options
  .text

export formatBadFile = (fileId) ->
  """<i class="bad-file">&lt;unknown file with ID #{fileId}&gt;</i>"""

###
vsivsi:file-collection creates an initial file of zero length; see
share.insert_func in
  https://github.com/vsivsi/meteor-file-collection/blob/master/src/gridFS.coffee
After upload (which is forbidden to take a zero-length file), the file
length gets set correctly; see the end of resumable_post_handler in
  https://github.com/vsivsi/meteor-file-collection/blob/master/src/resumable_server.coffee
We therefore don't display any file that is still in the zero-length state.
###
export formatEmptyFile = (fileId) ->
  """<i class="empty-file">(uploading file...)</i>"""

export formatFileDescription = (msg, file = null) ->
  file = findFile msg.file unless file?
  return formatBadFile msg.file unless file?
  return formatEmptyFile msg.file unless file.length
  """<i class="odd-file"><a href="#{urlToFile msg}">&lt;#{s.numberFormat file.length}-byte #{file.contentType} file &ldquo;#{file.filename}&rdquo;&gt;</a></i>"""

export formatVideo = (file, url, attrs = '') ->
  if file?.contentType
    """<video #{attrs}controls><source src="#{url}" type="#{file.contentType}"></video>"""
  else
    """<video #{attrs}controls><source src="#{url}"></video>"""

export formatFile = (msg, file = null) ->
  file = findFile msg.file unless file?
  return '' unless file? and file.length
  switch fileType file
    when 'image'
      """<img src="#{urlToFile msg}">"""
    when 'video'
      formatVideo file, urlToFile msg
    else  ## 'unknown'
      ''

export formatFilename = (msg, options) ->
  {orUntitled} = options if options?
  orUntitled ?= true
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

export formatTitleOrFilename = (msg, options) ->
  if msg.format and msg.title?.trim().length
    formatTitle msg.format, msg.title, {...options, id: msg._id}
  else
    formatFilename msg, options

export titleOrFilename = (msg) ->
  return unless msg?
  return msg.title if msg.title?.trim().length
  return unless msg.file?
  return findFile(msg.file)?.filename

#@stripHTMLTags = (html) ->
#  html.replace /<[^>]*>/gm, ''
