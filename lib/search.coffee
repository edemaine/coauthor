###
Search language parsing and formatting, as documented in README.md.
###

import {check} from 'meteor/check'

import {allEmoji} from './emoji'
import {escapeTag, unescapeTag} from './tags'

@escapeRegExp = (regex) ->
  ## https://stackoverflow.com/questions/3446170/escape-string-for-use-in-javascript-regex
  regex.replace /[\-\[\]\/\{\}\(\)\*\+\?\.\\\^\$\|]/g, "\\$&"

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

export parseSearch = (search, group) ->
  ## Quoted strings turn off separation by spaces.
  ## Last quoted strings doesn't have to be terminated.
  tokenRe = ///
    (\s+) |
    ([\|\(\)]) |
    ( (?: " (?:[^"\\]|\\.)* (?:"|$) | [^"\s\|\(\)\\] | \\. )+ )
  ///g
  wants = []         # array of Mongo queries that will be $and'd together
  options = [wants]  # array of wants that will be $or'd together
  stack = []         # stack of strict-ancestor options objects

  makeQuery = (options) ->
    parts =
      for option in options
        switch option.length
          when 0  # no wants: ignore
            continue
          when 1  # one want
            option = option[0]
            continue unless option?  # skip recursive empty queries
            option
          else    # multiple wants: $and together
            $and: option
    switch parts.length
      when 0  # no options
        null  ## special signal for nothing / bad search
      when 1  # one option
        parts[0]
      else    # multiple options: $or together
        $or: parts

  while (token = tokenRe.exec search)?
    continue if token[1]  ## ignore whitespace tokens

    if token[2]  # top-level grouping operators
      switch token[2]
        when '|'  # OR
          options.push wants = []
        when '('  # start group
          stack.push options
          options = [wants = []]
        when ')'  # end group
          childQuery = makeQuery options
          if stack.length
            options = stack.pop()
            wants = options[options.length-1]
            wants.push childQuery
          else  # extra ')': pretend there was a leading '('
            options = [wants = [childQuery]]
      continue

    ## Check for negation and/or leading commands followed by colon
    colon = /^-?(?:(?:regex|title|body|tag|emoji|by|root|is|isnt|not):)*/.exec token[0]
    colon = colon[0]
    ## Remove quotes (which are just used for avoiding space parsing).
    token = token[3].replace /(^|[^\\](?:\\\\)*)"((?:[^"\\]|\\[^])*)(?:"|$)/g, "$1$2"
    ## Remove leading colon part if we found one.
    ## (Can't have had quotes or escapes.)
    token = token[colon.length..]
    ## Remove escapes.
    token = token.replace /\\([:"\|\(\)\\])/g, '$1'
    ## Construct regex for token
    regexMode = 0 <= colon.indexOf 'regex:'
    colon = colon.replace /regex:/g, '' if regexMode
    regexForWord = (word) ->
      return unless word
      if regexMode
        regex = word
      else
        starStart = word[0] == '*'
        if starStart
          word = word[1..]
          return unless word
        starEnd = /[^\\]\*$/.test word
        if starEnd
          word = word[0...word.length-1]
          return unless word
        regex = escapeRegExp word
        ## Outside regex mode, lower-case letters are case-insensitive
        regex = caseInsensitiveRegExp regex
        regex = regex
        .replace /(^|[^\\])\\\*/g, '$1\\S*' # * in input becomes singly escaped
        .replace /\\\\\\\*/g, '\\*'  # \* in input becomes doubly escaped
        if not starStart and regex.match /^[\[\w]/  ## a or [aA]
          regex = "\\b#{regex}"
        if not starEnd and regex.match /[\w\]]$/  ## a or [aA]
          regex = "#{regex}\\b"
      regex = new RegExp regex
    ## Check for negation
    negate = colon[0] == '-'
    if negate
      colon = colon[1..]
    ## Colon commands
    switch colon
      when ''
        regex = regexForWord token
        continue unless regex?
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
        regex = regexForWord token
        continue unless regex?
        if negate
          wants.push title: $not: regex
        else
          wants.push title: regex
      when 'body:'
        regex = regexForWord token
        continue unless regex?
        if negate
          wants.push body: $not: regex
        else
          wants.push body: regex
      when 'tag:'
        if 0 <= equalIndex = token.indexOf '='
          key = token[...equalIndex]
          value = token[equalIndex+1..]
          if negate
            if value
              value = $ne: value
            else
              value = $nin: [true, value]
          else
            unless value
              value = $in: [true, value]
          wants.push "tags.#{escapeTag key}": value
        else
          wants.push "tags.#{escapeTag token}": $exists: not negate
      when 'emoji:'
        if 0 <= atIndex = token.indexOf '@'
          username = token[atIndex+1..]
          if username == 'me'
            username = Meteor.user()?.username
          else
            username = regexForWord username
          token = token[...atIndex]
        else
          username = undefined
        regex = regexForWord token
        emojis =
          for emoji in allEmoji group
            if regex?  # filter emoji if anything specified
              continue unless regex.test emoji.symbol
            "emoji.#{emoji.symbol}":
              if username?
                if negate
                  $not: username
                else
                  username
              else
                if negate
                  $ne: ''  # don't match any string
                else
                  $elemMatch: $ne: ''  # match any string
        if emojis.length
          if negate
            wants.push $and: emojis
          else
            wants.push $or: emojis
        else
          console.warn "No emoji match query #{regex}" if Meteor.isClient
      when 'by:'
        if token == 'me'
          regex = Meteor.user()?.username
        else
          token = token[1..] if token.startsWith '@'
          regex = regexForWord token
        continue unless regex?
        if negate
          wants.push coauthors: $not: regex
        else
          wants.push coauthors: regex
      when 'root:'
        if negate
          wants.push $and: [
            root: $ne: token
          ,
            _id: $ne: token
          ]
        else
          wants.push $or: [
            root: token
          ,
            _id: token
          ]
      when 'is:', 'isnt:', 'not:'
        negate = not negate if colon == 'isnt:' or colon == 'not:'
        switch token
          when 'root'
            if negate
              wants.push root: $ne: null
            else
              wants.push root: null
          when 'file'
            if negate
              wants.push file: null
            else
              wants.push file: $ne: null
          when 'published'
            if negate
              wants.push published: false
            else
              wants.push published: $ne: false
          when 'deleted', 'minimized', 'pinned', 'private', 'protected'
            if negate
              wants.push "#{token}": $ne: true
            else
              wants.push "#{token}": true
          when 'empty'
            if negate
              wants.push $or: [
                title: $ne: ''
              ,
                body: $ne: ''
              ,
                file: $ne: null
              ]
            else
              wants.push
                title: ''
              ,
                body: ''
              ,
                file: null
          else
            console.warn "Unknown 'is:' specification '#{token}'" if Meteor.isClient
  ## Close any still-open groups, pretending there are extra ')'s at the end.
  while stack.length
    childQuery = makeQuery options
    options = stack.pop()
    options[options.length-1].push childQuery
  makeQuery options

export formatSearch = (search, group) ->
  query = parseSearch search, group
  if query?
    formatted = formatParsedSearch query, group
    if /^(by|tagged) /.test formatted
      formatted = "messages #{formatted}"
    formatted
  else
    "invalid query '#{search}'"

formatParsedSearch = (query, group) ->
  keys = _.keys query
  if _.isEqual keys, ['$and']
    parts = (formatParsedSearch part for part in query.$and)
    if (emojis = checkAllEmoji parts, group) and emojis.prefix == 'no '
      return "no emoji#{emojis.suffix}"
    if parts.length == 2 and
       _.isEqual(['root'], _.keys query.$and[0]) and
       _.isEqual(['_id'], _.keys query.$and[1]) and
       _.isEqual query.$and[0].root, query.$and[1]._id
      return parts[0].replace /strictly /, ''
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
    else if parts.length == 2 and
       _.isEqual(['root'], _.keys query.$or[0]) and
       _.isEqual(['_id'], _.keys query.$or[1]) and
       _.isEqual query.$or[0].root, query.$or[1]._id
      parts[0].replace /strictly /, ''
    else if (emojis = checkAllEmoji parts, group) and not emojis.prefix
      "any emoji#{emojis.suffix}"
    else
      if parts.length > 1
        parts =
          for part in parts
            part = "(#{part})" if 0 <= part.indexOf ' AND '
            part
      parts.join ' OR '
  else if _.isEqual keys, ['$not']
    "#{formatParsedSearch query.$not} not"
  else if _.isEqual keys, ['title']
    if query.title == ''
      "empty title"
    else if _.isEqual query.title, $ne: ''
      "nonempty title"
    else
      "#{formatParsedSearch query.title} in title"
  else if _.isEqual keys, ['body']
    if query.body == ''
      "empty body"
    else if _.isEqual query.body, $ne: ''
      "nonempty body"
    else
      "#{formatParsedSearch query.body} in body"
  else if keys.length == 1 and keys[0].startsWith 'tags.'
    key = keys[0]
    tag = key[5..]
    value = query[key]
    subkeys = _.keys value
    if _.isEqual subkeys, ['$exists']
      if value.$exists
        "tagged '#{_.escape unescapeTag tag}'"
      else
        "not tagged '#{_.escape unescapeTag tag}'"
    else
      if subkeys.length == 1 and subkeys[0] in ['$in', '$nin', '$ne']
        value = value[subkeys[0]]
      (if subkeys.length == 1 and subkeys[0] in ['$nin', '$ne']
        'not '
      else
        ''
      ) +
      (if subkeys.length == 1 and subkeys[0] in ['$in', '$nin'] and
          _.isEqual value, [true, '']
        "empty tagged '#{_.escape unescapeTag tag}'"
      else if typeof value == 'string'
        "tagged '#{_.escape unescapeTag tag}' = '#{_.escape value}'"
      else
        "tagged '#{_.escape unescapeTag tag}' = #{_.escape JSON.stringify value}"
      )
  else if keys.length == 1 and keys[0].startsWith 'emoji.'
    key = keys[0]
    emoji = key[6..]
    value = query[key]
    if _.isEqual value, $elemMatch: $ne: ''
      "#{_.escape emoji} emoji"
    else if _.isEqual value, $ne: ''
      "no #{_.escape emoji} emoji"
    else
      notted = _.isEqual ['$not'], _.keys value
      value = value.$not if notted
      "#{if notted then 'no ' else ''}#{_.escape emoji} emoji by #{formatUserSearch value}"
  else if _.isEqual keys, ['coauthors']
    value = query[keys[0]]
    notted = _.isEqual ['$not'], _.keys value
    value = value.$not if notted
    "#{if notted then 'not ' else ''}by #{formatUserSearch value}"
  else if _.isEqual keys, ['root']
    root = query.root
    prefix = ''
    if _.isObject(root) and _.isEqual _.keys(root), ['$ne']
      root = root.$ne
      prefix = 'not '
    prefix +
    if root == null
      "root message"
    else
      "strictly in thread #{formatMessageSearch root}"
  else if _.isEqual keys, ['file']
    if _.isEqual query.file, null
      'not a file'
    else if _.isEqual query.file, {$ne: null}
      'a file'
    else
      "associated with file '#{_.escape query.file}'"
  else if _.isEqual keys, ['published']
    if _.isEqual query.published, false
      'unpublished'
    else if _.isEqual query.published, {$ne: false}
      'published'
    else
      "published: #{_.escape query.published}"
  else if _.isEqual keys, ['deleted']
    if _.isEqual query.deleted, true
      'deleted'
    else if _.isEqual query.deleted, {$ne: true}
      'not deleted'
    else
      "deleted: #{_.escape query.deleted}"
  else if _.isEqual keys, ['minimized']
    if _.isEqual query.minimized, true
      'minimized'
    else if _.isEqual query.minimized, {$ne: true}
      'not minimized'
    else
      "minimized: #{_.escape query.minimized}"
  else if _.isEqual keys, ['pinned']
    if _.isEqual query.pinned, true
      'pinned'
    else if _.isEqual query.pinned, {$ne: true}
      'not pinned'
    else
      "pinned: #{_.escape query.pinned}"
  else if _.isEqual keys, ['protected']
    if _.isEqual query.protected, true
      'protected'
    else if _.isEqual query.protected, {$ne: true}
      'not protected'
    else
      "protected: #{query.protected}"
  else if _.isEqual keys, ['private']
    if _.isEqual query.private, true
      'private'
    else if _.isEqual query.private, {$ne: true}
      'not private'
    else
      "private: #{_.escape query.private}"
  else if _.isRegExp query
    simplify = unbreakRegExp uncaseInsensitiveRegExp query.source
    if realRegExp simplify
      _.escape query.toString()
    else
      s = _.escape "“#{unescapeRegExp simplify}”"
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
  else if _.isString query
    _.escape "“#{query}”"
  else
    _.escape JSON.stringify query

formatUserSearch = (value) ->
  formatParsedSearch value
  .replace /^“(.*)”( whole-word)?$/, '$1' # simplify normal usernames

formatMessageSearch = (messageId) ->
  message = findMessage messageId
  title =
    if message?
      "“#{titleOrUntitled message}”"
    else
      "#{messageId}"
  url = pathFor 'message',
    group: message?.group ? wildGroup
    message: messageId
  """<a href="#{url}">#{title}</a>"""

emojiLike = /^(no )?([\-\w]+) emoji(.*)$/
checkAllEmoji = (parts, group) ->
  return unless parts?.length
  match = emojiLike.exec parts[0]
  return unless match?
  emoji =
    for part in parts
      match2 = emojiLike.exec part
      break unless match2? and
        match[1] == match2[1] and match[3] == match2[3]
      match2[2]
  if parts.length == emoji.length and
     _.isEqual emoji, (e.symbol for e in allEmoji group)
    prefix: match[1]
    suffix: match[3]

export maybeQuoteSearch = (search) ->
  if 0 <= search.indexOf ' '
    if 0 <= search.indexOf '"'
      if 0 <= search.indexOf "'"
        search = "\"#{search.replace /"/g, '"\'"\'"'}\""
        .replace /^""|""$/g, ''
      else
        search = "'#{search}'"
    else
      search = "\"#{search}\""
  search

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
      searchQuery = parseSearch search, group
      accessibleQuery = accessibleMessagesQuery group, findUser @userId
      return @ready() unless accessibleQuery? and searchQuery?
      Messages.find maybeAddRootsToQuery group, accessibleQuery, searchQuery
