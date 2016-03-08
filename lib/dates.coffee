@dateMin = (a, bs...) ->
  for b in bs
    if b.getTime() < a.getTime()
      a = b
  a

@dateMax = (a, bs...) ->
  for b in bs
    if b.getTime() > a.getTime()
      a = b
  a
