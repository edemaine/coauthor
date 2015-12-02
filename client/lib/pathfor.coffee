@pathFor = (route, data, hash) ->
  Blaze._globalHelpers.pathFor
    hash:
      route: route
      data: data
      hash: hash
