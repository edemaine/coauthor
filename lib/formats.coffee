@availableFormats = ['markdown', 'html', 'latex']  ## 'file' not an option for user
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
preprocessMathjaxBlocks = (text, replacer) ->
  blocks = []
  re = /[${}]|\\./g
  start = null
  braces = 0
  while (match = re.exec text)?
    #console.log match
    switch match[0]
      when '$'
        if start?
          if match.index > start+1  ## not opening $$
            if braces == 0
              blocks.push
                start: start
                end: match.index
              start = null
        else
          if blocks.length > 0 and blocks[blocks.length-1].end+1 == match.index
            blocks[blocks.length-1].end = match.index  ## closing $$
          else
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

postprocessCoauthorLinks = (text) ->
  ## xxx Not reactive, but should be.  E.g. won't update if image replaced.
  ## xxx More critically, won't load anything outside current subscription...
  text.replace ///(<img\s[^<>]*src\s*=\s*['"])coauthor:/?/?([a-zA-Z0-9]+)///ig,
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
  .replace ///(<a\s[^<>]*href\s*=\s*['"])coauthor:/?/?([a-zA-Z0-9]+)///ig,
    (match, p1, p2) ->
      msg = Messages.findOne p2
      if msg?
        p1 + pathFor 'message',
          group: msg.group
          message: msg._id
      else
        console.warn "Couldn't find group for message #{p2} (likely subscription issue)"
        match

latex2html = (tex) ->
  defs = {}
  tex = tex.replace /%.*$\n?/mg, ''
  tex = tex.replace /\\def\s*\\([a-zA-Z]+)\s*{((?:[^{}]|{[^{}]*})*)}/g, (match, p1, p2) ->
    defs[p1] = p2
    ''
  for def, val of defs
    console.log def, val
    tex = tex.replace new RegExp("\\\\#{def}\\s*", 'g'), val
  tex = '<P>' + tex
  .replace /\\\\/g, '[DOUBLEBACKSLASH]'
  .replace /\\(BY|YEAR)\s*{([^{}]*)}/g, '<SPAN STYLE="border: thin solid; margin-left: 0.5em; padding: 0px 4px; font-variant:small-caps">$2</SPAN>'
  .replace /\\protect\s*/g, ''
  .replace /\\textbf\s*{([^{}]*)}/g, '<B>$1</B>'
  .replace /\\textit\s*{([^{}]*)}/g, '<I>$1</I>'
  .replace /\\textsf\s*{([^{}]*)}/g, '<SPAN STYLE="font-family: sans-serif">$1</I>'
  .replace /\\emph\s*{([^{}]*)}/g, '<EM>$1</EM>'
  .replace /\\textsc\s*{([^{}]*)}/g, '<SPAN STYLE="font-variant:small-caps">$1</SPAN>'
  .replace /\\url\s*{([^{}]*)}/g, '<A HREF="$1">$1</A>'
  .replace /\\href\s*{([^{}]*)}\s*{([^{}]*)}/g, '<A HREF="$1">$2</A>'
  .replace /\\textcolor\s*{([^{}]*)}\s*{([^{}]*)}/g, '<SPAN STYLE="color: $1">$2</A>'
  .replace /\\colorbox\s*{([^{}]*)}\s*{([^{}]*)}/g, '<SPAN STYLE="background-color: $1">$2</A>'
  .replace /\\begin\s*{enumerate}/g, '<OL>'
  .replace /\\begin\s*{itemize}/g, '<UL>'
  .replace /\\item/g, '<LI>'
  .replace /\\end\s*{enumerate}/g, '</OL>'
  .replace /\\end\s*{itemize}/g, '</UL>'
  .replace /\\footnote\s*{((?:[^{}]|{[^{}]*})*)}/g, '[$1]'
  .replace /\\begin\s*{(problem|theorem|conjecture|lemma|corollary)}/g, (m, p1) -> "<BLOCKQUOTE><B>#{s.capitalize p1}:</B> "
  .replace /\\end\s*{(problem|theorem|conjecture|lemma|corollary)}/g, '</BLOCKQUOTE>'
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
  .replace /\n\n/g, '\n<P>\n'
  .replace /\[DOUBLEBACKSLASH\]/g, '\\\\'

@formats =
  file: (text, title) ->
    return text if title
    file = findFile text
    if file?
      if file.contentType[...6] == 'image/'
        text = "<img src='#{urlToFile file}'/>"
      else if file.contentType in ['video/mp4', 'video/ogg', 'video/webm']
        text = "<video controls><source src='#{urlToFile file}' type='#{file.contentType}'></video>"
      else
        text = "<i class='odd-file'><a href='#{urlToFile file}'>&lt;#{file.length}-byte #{file.contentType} file&gt;</a></i>"
    else
      text = "<i class='bad-file'>&lt;unknown file with ID #{text}&gt;</i>"
  markdown: (text, title) ->
    ## Escape all characters that can be (in particular, _s) that appear
    ## inside math mode, to prevent Marked from processing them.
    ## The Regex is exactly marked.js's inline.escape.
    text = preprocessMathjaxBlocks text, (block) ->
      block.replace /[\\`*{}\[\]()#+\-.!_]/g, '\\$&'
    #marked.Lexer.rules = {text: /^[^\n]+/} if title
    if title  ## use "single-line" version of Markdown
      text = marked.inlineLexer text, {}, marked.defaults
    else
      text = marked text
  latex: (text, title) ->
    latex2html text
  html: (text, title) ->
    text

postprocess = (html) ->
  #ketex.renderToString
  postprocessCoauthorLinks html

@formatBody = (format, body) ->
  if format of formats
    body = formats[format] body, false
  else
    console.warn "Unrecognized format '#{format}'"
  postprocess body

@formatTitle = (format, title) ->
  if format of formats
    title = formats[format] title, true
  else
    console.warn "Unrecognized format '#{format}'"
  ## Remove surrounding <P> block caused by Markdown and LaTeX formatters.
  title = title
  .replace /^\s*<P>\s*/i, ''
  .replace /\s*<\/P>\s*$/i, ''
  postprocess title

@stripHTMLTags = (html) ->
  html.replace /<[^>]*>/gm, ''

@indentLines = (text, indent) ->
  text.replace /^/gm, indent
