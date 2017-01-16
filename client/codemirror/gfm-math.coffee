CodeMirror = require "meteor/mizzao:sharejs-codemirror/node_modules/codemirror/lib/codemirror.js"

CodeMirror.defineMode "gfm-math", (config, modeConfig) ->
  CodeMirror.overlayMode CodeMirror.getMode(config, 'gfm'),
    token: (stream, state) ->
      if stream.eat '\\'
        stream.next()  ## escaped character
        null
      else if stream.eat '$'
        stream.eat '$'  ## possible second $
        braces = 0
        math = true
        while math
          stream.match /^[^${}\\]+/, true
          char = stream.next()
          break unless char?
          switch char
            when '\\'
              stream.next()  ## escaped character
            when '{'
              braces += 1
            when '}'
              braces -= 1
              braces = 0 if braces < 0  ## ignore extra }s
            when '$'
              if braces == 0
                stream.eat '$'  ## possible second $
                math = false
        'math'
      else
        stream.next()
        null
, 'gfm'

CodeMirror.defineMIME "text/x-gfm-math", "gfm-math"
