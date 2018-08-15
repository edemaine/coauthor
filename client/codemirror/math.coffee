CodeMirror = require 'codemirror'
require 'codemirror/addon/mode/overlay'

mathMode =
  startState: ->
    math: false
    braces: 0
  copyState: (s) ->
    math: s.math
    braces: s.braces
  token: (stream, state) ->
    startMath = ->
      state.braces = 0
      state.math = true
    unless state.math
      if stream.eat '$'
        stream.eat '$'  ## possible second $
        startMath()
      else
        if stream.eat '\\'
          if stream.match /^[\(\[]|begin\s*{(equation|eqnarray|align)\*?}/, true
            startMath()
          else
            stream.next()  ## escaped character
            return null
        else
          stream.match /^[^\\$]+/, true  ## skip irrelevant characters
          return null
    ## If we get here, we have state.math == true.
    while state.math
      stream.match /^[^${}\\]+/, true
      char = stream.next()
      break unless char?
      switch char
        when '\\'
          if stream.match /^[\]\)]|end\s*{(equation|eqnarray|align)\*?}/, true
            if state.braces == 0
              state.math = false
          else
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
