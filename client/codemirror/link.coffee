import {linkifyIt} from '/lib/markdown'
import 'codemirror/addon/mode/overlay'

export linkOverlay = ->
  # Cache last line and its links to avoid recomputation
  lastLine = null
  lastLinks = null

  lineLinks = (line) ->
    if line == lastLine
      return lastLinks
    lastLine = line
    lastLinks = linkifyIt.match line

  lineLinks: lineLinks
  token: (stream) ->
    links = lineLinks stream.string
    if links?
      for link in links
        continue if link.lastIndex <= stream.pos
        if stream.pos < link.index
          stream.pos = link.index
          return null
        if stream.pos < link.lastIndex
          stream.pos = link.lastIndex
          return 'link'
    stream.skipToEnd()
    null

export linkAtPos = (editor, pos) ->
  line = editor.getLine pos.line
  return null unless line?
  links = linkOverlay().lineLinks line
  return null unless links?
  for link in links
    if link.index <= pos.ch < link.lastIndex
      # Add pos field to position of start of link
      return {...link, pos: {...pos, ch: link.index}}
  null
