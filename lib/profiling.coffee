export isProfiling = Meteor.isServer and (
  Meteor.isDevelopment or Meteor.settings.coauthor?.profiling
)

## Functor for wrapping a function in a timer and a log statement,
## if `isProfiling` is true or a true `force` value gets passed in.
export profiling = (name, fun, force) ->
  if isProfiling or force
    (args...) ->
      start = new Date
      result = fun args...
      finish = new Date
      if typeof result == 'string'
        name += ": #{result}"
      console.log "#{name} [#{finish.getTime() - start.getTime()} ms]"
      result
  else
    fun

## Replacement for Meteor.startup that always profiles the called function.
export profilingStartup = (name, fun) ->
  Meteor.startup profiling name, fun, true
