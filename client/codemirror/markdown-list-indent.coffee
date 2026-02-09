## Inspired by CodeMirror's continuelist.js and
## https://github.com/joel-porquet/CodeMirror-markdown-list-autoindent

CodeMirror = require 'codemirror'

isMarkdownList = (cm, line) ->
  eolState = cm.getStateAfter line
  inner = CodeMirror.innerMode cm.getMode(), eolState
  (inner.mode.name == 'markdown' or inner.mode.helperType == 'markdown') and
  inner.state.list != false  # 0 counts as list

listItemRE = ///
  ^(\s*)            # group 1: leading indentation
  (                 # group 2: list marker
    [*+-]           #   unordered
  | (?: \d+[.)] )   #   ordered
  )
  (\s)              # group 3: required space after marker
  # The following are to extend the window where Tab indents
  ( \[ [x\ ] \] )?  # group 4: optional task checkbox token ([ ] / [x])
  \s*               # whitespace after marker/checkbox
///

orderedMarkerRE = ///
  ^
  (\d+)             # group 1: list item number
  ( [.)] )          # group 2: delimiter
  $
///

parseListItem = (cm, line) ->
  return unless isMarkdownList cm, line
  match = listItemRE.exec cm.getLine line
  return unless match?
  [prefix, indent, marker, markerSpace] = match
  orderedMatch = orderedMarkerRE.exec marker
  ordered = orderedMatch?
  {
    line
    indent
    marker
    markerSpace
    prefixLength: prefix.length
    columns: CodeMirror.countColumn indent, null, cm.getOption 'tabSize'
    ordered
    number: if ordered then Number orderedMatch[1]
    delimiter: if ordered then orderedMatch[2]
  }

cursorInPrefix = (range, item) ->
  range.head.ch <= item.prefixLength

indentUnit = (item) ->
  item.marker.length + item.markerSpace.length
 
setLeadingColumns = (cm, line, columns) ->
  text = cm.getLine line
  leading = text.search /\S|$/
  cm.replaceRange ' '.repeat(Math.max 0, columns),
    line: line
    ch: 0
  ,
    line: line
    ch: leading

lineLeadingColumns = (cm, line) ->
  text = cm.getLine line
  leading = /^\s*/.exec(text)[0]
  CodeMirror.countColumn leading, null, cm.getOption 'tabSize'

endOfListItem = (cm, line, columns) ->
  end = line
  line++
  while line <= cm.lastLine()
    break unless isMarkdownList cm, line
    item = parseListItem cm, line
    break if item? and item.columns <= columns
    end = line
    line++
  end

parentListItem = (cm, line, currentColumns) ->
  line--
  while line >= 0
    break unless isMarkdownList cm, line
    item = parseListItem cm, line
    if item? and item.columns < currentColumns
      return item
    line--
  return

replaceOrderedPrefix = (cm, line, number) ->
  item = parseListItem cm, line
  return unless item?.ordered
  prefix = "#{item.indent}#{number}#{item.delimiter}#{item.markerSpace}"
  cm.replaceRange prefix,
    line: line
    ch: 0
  ,
    line: line
    ch: item.prefixLength

findPreviousOrderedSibling = (cm, line, columns) ->
  line--
  while line >= 0
    return unless isMarkdownList cm, line
    item = parseListItem cm, line
    if item?
      return if item.columns < columns
      if item.columns == columns
        return if item.ordered then item
    line--
  return

findNextOrderedSibling = (cm, line, columns) ->
  while line <= cm.lastLine()
    return unless isMarkdownList cm, line
    item = parseListItem cm, line
    if item?
      return if item.columns < columns
      if item.columns == columns
        return if item.ordered then item
    line++
  return

renumberFollowingOrderedSiblings = (cm, startLine, columns, startNumber) ->
  expected = startNumber + 1
  line = startLine + 1
  while line <= cm.lastLine()
    break unless isMarkdownList cm, line
    item = parseListItem cm, line
    if item?
      break if item.columns < columns
      if item.columns == columns
        break unless item.ordered
        replaceOrderedPrefix cm, line, expected if item.number != expected
        expected++
    line++

normalizeOrderedLevelAround = (cm, line, columns) ->
  if (previousSibling = findPreviousOrderedSibling cm, line, columns)?
    return renumberFollowingOrderedSiblings cm, previousSibling.line, columns, previousSibling.number
  first = findNextOrderedSibling cm, line, columns
  return unless first?
  replaceOrderedPrefix cm, first.line, 1 if first.number != 1
  renumberFollowingOrderedSiblings cm, first.line, columns, 1

collectTargets = (cm, computeNewColumns) ->
  ranges = cm.listSelections()
  targets = []
  seen = new Set
  for range in ranges
    return [] unless range.empty()
    line = range.head.line
    item = parseListItem cm, line
    return [] unless item?
    return [] unless cursorInPrefix range, item
    continue if seen.has line
    seen.add line
    newColumns = computeNewColumns cm, line, item
    targets.push
      line: line
      oldColumns: item.columns
      newColumns: newColumns
      delta: newColumns - item.columns
      endLine: endOfListItem cm, line, item.columns
      ordered: item.ordered
  targets

shiftTargets = (cm, targets) ->
  shifted = new Set
  for {line, endLine, delta} in targets
    rangeLine = line
    while rangeLine <= endLine
      if /^\s*$/.test cm.getLine rangeLine
        rangeLine++
        continue
      unless shifted.has rangeLine
        columns = lineLeadingColumns cm, rangeLine
        setLeadingColumns cm, rangeLine, columns + delta
        shifted.add rangeLine
      rangeLine++

renumberTargets = (cm, targets) ->
  for {line, newColumns, ordered} in targets when ordered
    current = parseListItem cm, line
    continue unless current?.ordered
    previousSibling = findPreviousOrderedSibling cm, line, newColumns
    number = if previousSibling? then previousSibling.number + 1 else 1
    replaceOrderedPrefix cm, line, number if current.number != number
    renumberFollowingOrderedSiblings cm, line, newColumns, number
  for {line, oldColumns, newColumns, ordered} in targets when ordered and oldColumns != newColumns
    normalizeOrderedLevelAround cm, line, oldColumns

listIndentCommand = (cm, computeNewColumns) ->
  return CodeMirror.Pass if cm.getOption 'disableInput'
  targets = collectTargets cm, computeNewColumns
  return CodeMirror.Pass unless targets.length
  cm.operation ->
    shiftTargets cm, targets
    renumberTargets cm, targets
  true

CodeMirror.commands.indentMarkdownList = (cm) ->
  listIndentCommand cm, (cm, line, item) ->
    item.columns + indentUnit item

CodeMirror.commands.dedentMarkdownList = (cm) ->
  listIndentCommand cm, (cm, line, item) ->
    parent = parentListItem cm, line, item.columns
    return 0 unless parent?
    naturalChildColumns = parent.columns + indentUnit parent
    if item.columns > naturalChildColumns
      naturalChildColumns
    else
      parent.columns
