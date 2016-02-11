@availableFormats = ['html', 'markdown']  ## 'file' not an option for user
@mathjaxFormats = availableFormats  ## Don't do tex2jax for files

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

marked.InlineLexer.rules.gfm.url =
  ///^((coauthor:/?/?|https?://)[^\s<]+[^<.,:;"')\]\s])///

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

@formats =
  file: (body) ->
    file = findFile body
    if file?
      if file.contentType[...6] == 'image/'
        body = "<img src='#{urlToFile file}'/>"
      else
        body = "<i><a href='#{urlToFile file}'>&lt;#{file.length}-byte #{file.contentType} file&gt;</a></i>"
    else
      body = "<i>&lt;unknown file with ID #{body}&gt;</i>"
  markdown: (body) ->
    ## Escape all characters that can be (in particular, _s) that appear
    ## inside math mode, to prevent Marked from processing them.
    ## The Regex is exactly marked.js's inline.escape.
    #console.log 'before', body
    body = preprocessMathjaxBlocks body, (block) ->
      block.replace /[\\`*{}\[\]()#+\-.!_]/g, '\\$&'
    #console.log 'after', body
    body = marked body
  html: (body) ->
    body

@formatBody = (format, body) ->
  if format of formats
    body = formats[format] body
  else
    console.warn "Unrecognized format '#{format}'"
  postprocessCoauthorLinks body
