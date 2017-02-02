## pathFor/urlFor want arguments for wildcards; we just want the '*'
wild =
  0: '*'

@pathFor = (route, data, hash) ->
  Blaze._globalHelpers.pathFor
    hash:
      route: route
      data: _.extend data, wild
      hash: hash

@urlFor = (route, data, hash) ->
  Blaze._globalHelpers.urlFor
    hash:
      route: route
      data: _.extend data, wild
      hash: hash
    0: '*'
