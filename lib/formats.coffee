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
  re = /[{}]|\$\$?|\\(begin|end)\s*{((?:equation|eqnarray|align|alignat|gather|CD)\*?)}|(\\par(?![a-zA-Z])|\n[ \f\r\t\v]*\n\s*)|\\./g
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
latex2htmlVerb = (tex) ->
  tex.replace /\\begin\s*{verbatim}([^]*?)\\end\s*{verbatim}/g,
    (match, verb) -> "<pre>#{latexEscape verb}</pre>"
  .replace /\\url\s*{([^{}]*)}/g, (match, url) ->
    url = latexURL url
    """<a href="#{url}">#{latexEscape url}</a>"""
  .replace /\\href\s*{([^{}]*)}\s*{((?:[^{}]|{[^{}]*})*)}/g,
    (match, url, text) ->
      url = latexURL url
      """<a href="#{url}">#{text}</a>"""
  .replace /\\begin\s*{CJK(\*?)}\s*{UTF8}\s*{[^{}]*}(.*?)\\end{CJK\*?}/g,
    (match, star, text) ->
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

latex2htmlDef = (tex) ->
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
    r = ///
      ({?)     # allow {\macro} notation to force space after macro
      \\(#{_.keys(defs).join '|'})
      (?![a-zA-z])  # ensure full-word match
      \s*      # consume spaces after \macro, like TeX does
      (?:{})?  # allow \macro{} notation to force space after macro
      (}?)     # allow {\macro} notation to force space after macro
    ///g
    while r.test tex
      tex = tex.replace r, (match, left, def, right) ->
        left = right = '' if left and right
        left + defs[def] + right
  tex

texAlign =
  raggedleft: 'right'
  raggedright: 'left'
  centering: 'center'

## Process all commands starting with \ followed by a letter a-z.
## This is not a valid escape sequence in Markdown, so can be safely supported
## in Markdown too.
latex2htmlCommandsAlpha = (tex, math) ->
  tex = tex
  ## Process tabular environments first in order to split cells at &
  ## (so e.g. \bf is local to the cell)
  .replace /\\begin\s*{tabular}\s*{([^{}]*)}([^]*?)\\end\s*{tabular}/g, (m, cols, body) ->
    cols = cols.replace /|/g, '' # not yet supported
    body = body.replace /\\hline\s*|\\cline\s*{[^{}]*}/g, '' # not yet supported
    skip = (0 for colnum in [0...cols.length])
    '<table>' +
      (for row in body.split /(?:\\\\|\[DOUBLEBACKSLASH\])/ #(?:\s*\\(?:hline|cline\s*{[^{}]*}))?/
         #console.log row
         continue unless row.trim()
         "<tr>\n" +
         (for col, colnum in row.split '&'
            if skip[colnum]
              skip[colnum] -= 1
              continue
            align = cols[colnum]
            attrs = ''
            style = ''
            ## "If you want to use both \multirow and \multicolumn on the same
            ## entry, you must put the \multirow inside the \multicolumn"
            ## [http://ctan.mirrors.hoobly.com/macros/latex/contrib/multirow/multirow.pdf]
            if (match = /\\multicolumn\s*(\d+|{\s*(\d+)\s*})\s*(\w|{([^{}]*)})\s*{((?:[^{}]|{(?:[^{}]|{[^{}]*})*})*)}/.exec col)?
              attrs += " colspan=\"#{match[2] ? match[1]}\""
              align = match[4] ? match[3]
              col = match[5]
            ## In HTML, rowspan means that later rows shouldn't specify <td>s
            ## for that column, while in LaTeX, they are still present.
            if (match = /\\multirow\s*(\d+|{\s*(\d+)\s*})\s*(\*|{([^{}]*)})\s*{((?:[^{}]|{(?:[^{}]|{[^{}]*})*})*)}/.exec col)?
              rowspan = parseInt match[2] ? match[1]
              skip[colnum] += rowspan - 1
              attrs += " rowspan=\"#{rowspan}\""
              style = 'vertical-align: middle; '
              #width = match[4] ? match[3]
              col = match[5]
            attrs +=
              switch align
                when 'c'
                  " style=\"#{style}text-align: center\""
                when 'l'
                  " style=\"#{style}text-align: left\""
                when 'r'
                  " style=\"#{style}text-align: right\""
                else
                  style
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
    old = tex
    tex = tex
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
    break if old == tex
  listStyles = []
  listCounts = []
  tex = tex
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
  .replace /\\begin\s*{(problem|question|idea|theorem|conjecture|lemma|corollary|fact|observation|proposition|claim|definition|example)}(\s*\[([^\]]*)\])?/g, (m, env, x, opt) -> """<blockquote class="thm"><p><b>#{capitalize env}#{if opt then " (#{opt})" else ''}:</b> """
  .replace /\\end\s*{(problem|question|idea|theorem|conjecture|lemma|corollary|fact|observation|proposition|claim|definition|example)}/g, '</blockquote>'
  .replace /\\begin\s*{(quote)}/g, '<blockquote><p>'
  .replace /\\end\s*{(quote)}/g, '</blockquote>'
  .replace /\\begin\s*{(proof|pf)}(\s*\[((?:[^\]{}]|{(?:[^{}]|{[^{}]*})})*)\])?/g, (m, env, x, opt) -> "<b>Proof#{if opt then " (#{opt})" else ''}:</b> "
  .replace /\\end\s*{(proof|pf)}/g, ' <span class="pull-right">&#8718;</span></p><p class="clearfix">'
  .replace /\\begin\s*{center}/g, '<div class="center">'
  .replace /\\end\s*{center}/g, '</div>'
  .replace latexSimpleCommandsRe, (match, name) -> latexSimpleCommands[name]
  ## The following tweaks are not LaTeX actually, but useful in all modes,
  ## so we do them here.
  .replace /\b[0-9]+(x[0-9]+)+\b/ig, (match) ->
     match.replace /x/ig, '\u00a0×\u00a0'

## "Light" LaTeX support, using only commands that start with a letter a-z,
## so are safe to process in Markdown.  No accent support.
latex2htmlLight = (tex, me) ->
  tex = latex2htmlVerb tex
  tex = latex2htmlDef tex
  ## After \def expansion and verbatim processing, protect math
  [tex, math] = preprocessKaTeX tex
  ## After math extraction, process @mentions
  tex = processAtMentions tex, me
  tex = latex2htmlCommandsAlpha tex, math
  [tex, math]

## Full LaTeX support, including all supported commands and symbols
## (% make comments, ~ makes nonbreaking space, etc.).
latex2html = (tex, me) ->
  tex = latex2htmlVerb tex
  tex = latexStripComments tex
  ## Paragraph detection must go before any macro expansion (which eat \n's)
  tex = tex.replace /\n\n+/g, '\n\\par\n'
  tex = latex2htmlDef tex
  ## After \def expansion and verbatim processing, protect math
  [tex, math] = preprocessKaTeX tex
  ## After math extraction, process @mentions
  tex = processAtMentions tex, me
  ## Start initial paragraph
  tex = '<p>' + tex
  ## Commands
  tex = tex.replace /\\\\/g, '[DOUBLEBACKSLASH]'
  tex = latex2htmlCommandsAlpha tex, math
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
  [tex, math]

formats =
  markdown: (text, title, me) ->
    ## Escape all characters that can be (in particular, _s) that appear
    ## inside math mode, to prevent Marked from processing them.
    ## The Regex is exactly marked.js's inline.escape.
    #text = replaceMathBlocks text, (block) ->
    #  block.replace /[\\`*{}\[\]()#+\-.!_]/g, '\\$&'
    #marked.Lexer.rules = {text: /^[^\n]+/} if title
    ## First extract Markdown verbatim environments (backticks) to prevent
    ## LaTeX processing on them (especially math mode, so $ is inert in code).
    [text, ticks] = preprocessMarkdownTicks text
    ## Support what we can of LaTeX before doing Markdown conversion.
    [text, math] = latex2htmlLight text, me
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
    [text, math]
  latex: (text, title, me) ->
    latex2html text, me
  html: (text, title) ->
    linkify text

export coauthorLinkBodyRe = "/?/?([a-zA-Z0-9]+)"
export coauthorLinkBodyHashRe = "#{coauthorLinkBodyRe}(#[a-zA-Z0-9]*)?"
export coauthorLinkRe = "coauthor:#{coauthorLinkBodyRe}"
export coauthorLinkHashRe = "coauthor:#{coauthorLinkBodyHashRe}"

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

imageTitleAndWarning = (msg) ->
  ## xxx Should we subscribe to the linked message when we can't find it?
  msg = findMessage msg
  title = titleOrFilename(msg) ? ''
  attrs = prefix = ''
  if msg? and (msg.deleted or not msg.published)
    classes = []
    classes.push 'deleted' if msg.deleted
    classes.push 'unpublished' unless msg.published
    attrs += """class="#{classes.join ' '}" """
    warning = "WARNING: Image is #{classes.join(' and ').toUpperCase()} so will NOT BE VISIBLE to most users!"
    prefix = """<div class="warning #{classes.join ' '}">#{warning.replace /[A-Z]{2,}/g, "<b>$&</b>"}</div>"""
    title = "#{warning} #{title}"
  attrs += """title="#{escapeForQuotedHTML title}" """ if title
  {attrs, prefix}

postprocessCoauthorLinks = (text) ->
  text
  .replace ///(<img\s[^<>]*src\s*=\s*['"])#{coauthorLinkRe}///ig,
    (match, img, id) ->
      img + urlToFile id
  .replace ///(<a\s[^<>]*)(href\s*=\s*['"])#{coauthorLinkHashRe}((['"]>)coauthor:([^<>]*)(</a>))?///ig,
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
          a += """class="coauthor-link" """
          suffix = """#{suffixLeft}<img src="#{Meteor.absoluteUrl 'favicon32.png'}" class="natural">#{escapeForHTML title}#{suffixRight}"""
      suffix ?= ''
      a + href + url + suffix
  .replace ///(<img\s[^<>]*)(src\s*=\s*['"])(#{fileUrlPrefixPattern}[^'"]*)(['"][^<>]*>)///ig,
    (match, img, src, url, isFile, isInternalFile, suffix) ->
      ## xxx Should we subscribe to the linked message when we can't find it?
      if isFile
        msg = findMessage url2file url
        return match unless msg?
        {attrs, prefix} = imageTitleAndWarning msg
        fileId = msg.file
      else
        fileId = url2internalFile url
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
        "#{slash}&#8203;"  ## Add zero-width space after every slash group

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
  [text, math]

putMathBack = (tex, math) ->
  ## Restore math
  tex.replace /!MATH(\d+)ENDMATH!/g, (match, id) -> _.escape math[id].all

postprocessKaTeX = (text, math, initialBold) ->
  return text unless math.length
  macros = {}  ## shared across multiple math expressions within same body
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
  [text, ticks]

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
  {leaveTeX, bold, me, id} = options if options?

  ## Markdown format is special because it processes @mentions
  ## at a specific time (after verbatim extraction).

  ## LaTeX and Markdown formats are special because they do their own math
  ## and @mention preprocessing at a specific time during its formatting.
  ## Other formats (currently just HTML) don't touch math,
  ## so we need to preprocess here.
  if format in ['latex', 'markdown']
    [text, math] = formats[format] text, isTitle, me
  else
    [text, math] = preprocessKaTeX text
    text = processAtMentions text, me
    if format of formats
      text = formats[format] text, isTitle
    else
      console.warn "Unrecognized format '#{format}'"

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
    text = postprocessKaTeX text, math, bold
  text = linkify text  ## Extra support for links, unliked LaTeX
  text = postprocessCoauthorLinks text
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
  text

formatEitherSafe = (isTitle, format, text, options) ->
  try
    formatEither isTitle, format, text, options
  catch e
    console.error e.stack ? e.toString()
    if isTitle
      """
        <span class="label label-danger">Formatting error (bug in Coauthor)</span>
        <code>#{_.escape text}</code>
      """
    else
      """
        <div class="alert alert-danger">Formatting error (bug in Coauthor): #{e.toString()}</div>
        <pre>#{_.escape text}</pre>
      """

export formatBody = (format, body, options) ->
  formatEitherSafe false, format, body, options

export formatTitle = (format, title, options) ->
  formatEitherSafe true, format, title, options

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
