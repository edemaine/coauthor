@pathFor = (route, data, hash) ->
  Blaze._globalHelpers.pathFor
    hash:
      route: route
      data: data
      hash: hash

@urlFor = (route, data, hash) ->
  Blaze._globalHelpers.urlFor
    hash:
      route: route
      data: data
      hash: hash
