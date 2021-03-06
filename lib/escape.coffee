DOT = '[DOT]'
DOLLAR = '[DOLLAR]'

export escapeKey = (key) ->
  return key unless key
  key
  .replace /\./g, DOT
  .replace /\$/g, DOLLAR

export unescapeKey = (key) ->
  return key unless key
  key
  .replace /\[DOT\]/g, '.'
  .replace /\[DOLLAR\]/g, '$'

export validKey = (key) ->
  key and key.indexOf(DOT) < 0 and key.indexOf(DOLLAR) < 0
