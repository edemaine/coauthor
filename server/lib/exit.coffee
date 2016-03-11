## Based on https://github.com/meteor/meteor/blob/dc3cd6eb92f2bdd1bb44000cdd6abd1e5d0285b1/tools/tool-env/cleanup.js
@onExit = (callback) ->
  process.on 'exit', callback
  for signal in ['SIGINT', 'SIGHUP', 'SIGTERM']
    process.once signal, ->
      callback()
      process.kill process.pid, signal
