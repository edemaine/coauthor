###
SEARCH LANGUAGE:

* If you write a word, the default behavior is to search as a whole word
  in message's title or body.
* title:... matches in the title only
* body:... matches in the body only
* Use asterisks to search for partial words instead of full words:
  * `word*` to search for prefix word
  * `*word` to search for suffix word
  * `*word*` to search for infix word
  * `word*word` to search for words starting and ending in particular way, etc.
* Lower-case letters are case insensitive,
  while upper-case letters are case sensitive.
* regex:... matches using a regular expression instead of a word.
  Case sensitive.
* Prefix any of the above with a minus (`-`) to negate the match.
* Connecting queries via spaces does an implicit AND (like Google)
* Use quotes ('...' or "...") to prevent this behavior.  For example,
  search for "this phrase" or title:"this phrase" or regex:"this regex"
  or title:regex:"this regex" or -title:"this phrase".
* tag:... does an exact match for a specified tag.  It can be negated with -,
  but does not behave specially with regex: or *s.
###

escapeRegExp = (regex) ->
  ## https://stackoverflow.com/questions/3446170/escape-string-for-use-in-javascript-regex
  #s.replace /[\-\[\]\/\{\}\(\)\*\+\?\.\\\^\$\|]/g, "\\$&"
  ## Intentionally omitting * which we're defining in parseSearch
  regex.replace /[\-\[\]\/\{\}\(\)\+\?\.\\\^\$\|]/g, "\\$&"

caseInsensitiveRegExp = (regex) ->
  regex.replace /[a-z]/g, (char) -> "[#{char}#{char.toUpperCase()}]"

uncaseInsensitiveRegExp = (regex) ->
  regex.replace /\[([a-z])([A-Z])\]/g, (match, lower, upper) ->
    if lower.toUpperCase() == upper
      lower
    else
      match

unbreakRegExp = (regex) ->
  regex.replace /^\\b|\\b$/g, ''

realRegExp = (regex) ->
  ## Returns whether s uses any "real" regex features, i.e.,
  ## whether it can be unescaped to return to a string.
  /[^\\]([\-\[\]\/\{\}\(\)\*\+\?\.\^\$\|]|\\[a-zA-Z])/.test regex

unescapeRegExp = (regex) ->
  regex.replace /\\(.)/g, "$1"

@parseSearch = (search) ->
  ## Quoted strings turn off separation by spaces.
  ## Last quoted strings doesn't have to be terminated.
  tokenRe = /(\s+)|((?:"[^"]*"|'[^']*'|[^'"\s])+)('[^']*$|"[^"]*$)?|'([^']*)$|"([^"]*)$/g
  wants = []
  while (token = tokenRe.exec search)?
    continue if token[1]  ## ignore whitespace tokens
    ## Check for negation and/or leading commands followed by colon
    colon = /^-?(?:(?:regex|title|body|tag):)*/.exec token[0]
    colon = colon[0]
    ## Remove quotes (which are just used for avoiding space parsing).
    if token[4]
      token = token[4]  ## unterminated initial '
    else if token[5]
      token = token[5]  ## unterminated initial "
    else
      token = (token[2].replace /"([^"]|\\")*"|'([^']|\\')*'/g, (match) ->
        match.substring 1, match.length-1
      ) + (token[3] ? '').substring 1
    ## Remove leading colon part if we found one.
    ## (Can't have had quotes or escapes.)
    token = token.substring colon.length
    continue unless token
    ## Remove escapes.
    token = token.replace /\\([:'"\\])/g, '$1'
    ## Construct regex for token
    if 0 <= colon.indexOf 'regex:'
      regex = token
      colon = colon.replace /regex:/g, ''
    else
      starStart = token[0] == '*'
      if starStart
        token = token.substring 1
        continue unless token
      starEnd = token[token.length-1] == '*'
      if starEnd
        token = token.substring 0, token.length-1
        continue unless token
      regex = escapeRegExp token
      ## Outside regex mode, lower-case letters are case-insensitive
      regex = caseInsensitiveRegExp regex
      regex = regex.replace /\*/g, '\\S*'
      if not starStart and regex.match /^[\[\w]/  ## a or [aA]
        regex = "\\b#{regex}"
      if not starEnd and regex.match /[\w\]]$/  ## a or [aA]
        regex = "#{regex}\\b"
    regex = new RegExp regex
    ## Check for negation
    negate = colon[0] == '-'
    if negate
      colon = colon.substring 1
    ## Colon commands
    switch colon
      when ''
        if negate
          wants.push title: $not: regex
          wants.push body: $not: regex
        else
          wants.push $or: [
            title: regex
          ,
            body: regex
          ]
      when 'title:'
        if negate
          wants.push title: $not: regex
        else
          wants.push title: regex
      when 'body:'
        if negate
          wants.push body: $not: regex
        else
          wants.push body: regex
      when 'tag:'
        wants.push "tags.#{escapeTag token}": $exists: not negate
  if wants.length == 1
    wants[0]
  else
    $and: wants

@formatSearch = (search) ->
  query = parseSearch search
  if query?
    formatted = formatParsedSearch query
  else
    "invalid query &ldquo;#{search}&rdquo;"

formatParsedSearch = (query) ->
  keys = _.keys query
  if _.isEqual keys, ['$and']
    parts = (formatParsedSearch part for part in query.$and)
    if parts.length > 1
      parts =
        for part in parts
          part = "(#{part})" if 0 <= part.indexOf ' OR '
          part
    for i in [parts.length-1..1]
      if _.isEqual(['title'], _.keys query.$and[i-1]) and
         _.isEqual(['$not'], _.keys query.$and[i-1].title) and
         _.isEqual(['body'], _.keys query.$and[i]) and
         _.isEqual(['$not'], _.keys query.$and[i].body) and
         _.isEqual query.$and[i-1].title.$not, query.$and[i].body.$not
        parts[i-1..i] = parts[i-1].replace /in title$/, 'in title nor body'
    for i in [1...parts.length]
      if parts[i-1][-17..] == ' in title or body' and
         parts[i][-17..] == ' in title or body'
        parts[i-1] = parts[i-1][...-17]
      else if parts[i-1][-9..] == ' in title' and
              parts[i][-9..] == ' in title'
        parts[i-1] = parts[i-1][...-9]
      else if parts[i-1][-8..] == ' in body' and
              parts[i][-8..] == ' in body'
        parts[i-1] = parts[i-1][...-8]
    parts.join ' AND '
  else if _.isEqual keys, ['$or']
    parts = (formatParsedSearch part for part in query.$or)
    if parts.length == 2 and
       _.isEqual(['title'], _.keys query.$or[0]) and
       _.isEqual(['body'], _.keys query.$or[1]) and
       _.isEqual query.$or[0].title, query.$or[1].body
      parts[0].replace /in title$/, 'in title or body'
    else
      parts.join ' OR '
  else if _.isEqual keys, ['$not']
    "#{formatParsedSearch query.$not} not"
  else if _.isEqual keys, ['title']
    "#{formatParsedSearch query.title} in title"
  else if _.isEqual keys, ['body']
    "#{formatParsedSearch query.body} in body"
  else if keys.length == 1 and keys[0][...5] == 'tags.'
    key = keys[0]
    value = query[key]
    if _.isEqual _.keys(value), ['$exists']
      if value.$exists
        "tagged '#{unescapeTag key[5..]}'"
      else
        "not tagged '#{unescapeTag key[5..]}'"
    else
      "tag #{key[5..]}: #{JSON.stringify value}"
  else if _.isRegExp query
    simplify = unbreakRegExp uncaseInsensitiveRegExp query.source
    if realRegExp simplify
      query.toString()
    else
      s = "“#{unescapeRegExp simplify}”"
      if /[A-Z]/.test s
        s += ' case-sensitive'
      #else
      #  s += ' case-insensitive'
      if /^\\b/.test(query.source) and /\\b$/.test query.source
        s += ' whole-word'
      else if /^\\b/.test query.source
        s += ' prefix'
      else if /\\b$/.test query.source
        s += ' suffix'
      #else
      #  s += ' substring'
      s
  else
    JSON.stringify query

## Pure regex searching
#@searchQuery = (search) ->
#  $or: [
#    title: $regex: search
#  ,
#    body: $regex: search
#  ]

if Meteor.isServer
  Meteor.publish 'messages.search', (group, search) ->
    check group, String
    check search, String
    @autorun ->
      query = accessibleMessagesQuery group, findUser @userId
      return @ready() unless query?
      query = $and: [
        query
        parseSearch search
      ]
      Messages.find addRootsToQuery query
