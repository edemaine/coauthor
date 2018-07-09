## pathFor/urlFor want arguments for wildcards; we just want the '*'
wild =
  0: '*'

## Get IronRouter's original definitions
ironPathFor = Blaze._globalHelpers.pathFor
ironUrlFor = Blaze._globalHelpers.urlFor

@pathFor = (route, data, hash) ->
  data = data.hash if data.hash?  ## when given Spacebars.kw
  hash = data.hash if data.hash?  ## when given Spacebars.kw
  data = data.data if data.data?  ## when given all data in data attribute
  ironPathFor
    hash:
      route: route
      data: _.extend data, wild
      query: data.query
      hash: hash
    0: '*'

@urlFor = (route, data, hash) ->
  data = data.hash if data.hash?  ## when given Spacebars.kw
  hash = data.hash if data.hash?  ## when given Spacebars.kw
  data = data.data if data.data?  ## when given all data in data attribute
  ironUrlFor
    hash:
      route: route
      data: _.extend data, wild
      query: data.query
      hash: hash
    0: '*'

## Replace existing helpers
Blaze._globalHelpers.pathFor = pathFor
Blaze._globalHelpers.urlFor = urlFor
