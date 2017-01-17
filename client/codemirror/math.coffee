CodeMirror = require "meteor/mizzao:sharejs-codemirror/node_modules/codemirror/lib/codemirror.js"

mathMode =
  startState: ->
    math: false
    braces: 0
  copyState: (s) ->
    math: s.math
    braces: s.braces
  token: (stream, state) ->
    unless state.math
      if stream.eat '$'
        stream.eat '$'  ## possible second $
        state.braces = 0
        state.math = true
      else
        if stream.eat '\\'
          stream.next()  ## escaped character
        else
          stream.match /^[^\\$]+/, true
        return null
    ## If we get here, we have state.math == true.
    while state.math
      stream.match /^[^${}\\]+/, true
      char = stream.next()
      break unless char?
      switch char
        when '\\'
          stream.next()  ## escaped character
        when '{'
          state.braces += 1
        when '}'
          state.braces -= 1
          state.braces = 0 if state.braces < 0  ## ignore extra }s
        when '$'
          if state.braces == 0
            stream.eat '$'  ## possible second $
            state.math = false
    'math'

CodeMirror.defineMode "gfm-math", (config, modeConfig) ->
  CodeMirror.overlayMode CodeMirror.getMode(config, 'gfm'), mathMode, 'gfm'

CodeMirror.defineMIME "text/x-gfm-math", "gfm-math"

CodeMirror.defineMode "html-math", (config, modeConfig) ->
  CodeMirror.overlayMode CodeMirror.getMode(config,
    name: 'xml'
    htmlMode: true
  ), mathMode, 'xml'

CodeMirror.defineMIME "text/x-html-math", "html-math"
