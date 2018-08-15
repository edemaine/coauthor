CodeMirror = require 'codemirror'

modifier =
  if CodeMirror.keyMap.default == CodeMirror.keyMap.macDefault
    "Cmd"
  else
    "Ctrl"
CodeMirror.keyMap.default["#{modifier}-S"] = "save"

## For now, ignore save actions (Ctrl-S in normal mode, :w in vim mode, etc.),
## as everything is immediately uploaded to the server, and server decides
## when to update the database.
CodeMirror.commands.save = ->
