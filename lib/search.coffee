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
###

escapeRegExp = (s) ->
  ## https://stackoverflow.com/questions/3446170/escape-string-for-use-in-javascript-regex
  #s.replace /[\-\[\]\/\{\}\(\)\*\+\?\.\\\^\$\|]/g, "\\$&"
  ## Intentionally omitting * which we're defining in parseSearch
  s.replace /[\-\[\]\/\{\}\(\)\+\?\.\\\^\$\|]/g, "\\$&"

@parseSearch = (search) ->
  ## Quoted strings turn off separation by spaces.
  ## Last quoted strings doesn't have to be terminated.
  tokenRe = /(\s+)|((?:"[^"]*"|'[^']*'|[^'"\s])+)('[^']*$|"[^"]*$)?|'([^']*)$|"([^"]*)$/g
  wants = []
  while (token = tokenRe.exec search)?
    continue if token[1]  ## ignore whitespace tokens
    ## Check for negation and/or leading commands followed by colon
    colon = /^-?(?:(?:regex|title|body):)*/.exec token[0]
    colon = colon[0]
    ## Remove quotes (which are just used for avoiding space parsing).
    if token[4]
      token = token[4]  ## unterminated initial '
    else if token[5]
      token = token[5]  ## unterminated initial "
    else
      token = (token[2].replace /"[^"]*"|'[^']*'/g, (match) ->
        match.substring 1, match.length-1
      ) + (token[3] ? '').substring 1
    ## Remove leading colon part if we found one.  (Can't have had quotes.)
    token = token.substring colon.length
    continue unless token
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
      .replace /[a-z]/g, (char) -> "[#{char}#{char.toUpperCase()}]"
      regex = regex.replace /\*/g, '\\S*'
      regex = "\\b#{regex}" unless starStart
      regex = "#{regex}\\b" unless starEnd
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
  if wants.length == 1
    wants[0]
  else
    $and: wants

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
