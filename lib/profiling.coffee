export isProfiling = Meteor.isServer and (
  Meteor.isDevelopment or Meteor.settings.coauthor?.profiling
)

export profiling = (fun, name) ->
  if isProfiling
    (args...) ->
      start = new Date
      result = fun args...
      finish = new Date
      console.log name, '@', finish.getTime() - start.getTime(), 'ms'
      result
  else
    fun
