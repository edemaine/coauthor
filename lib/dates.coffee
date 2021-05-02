export dateMin = (a, bs...) ->
  for b in bs
    if b.getTime() < a.getTime()
      a = b
  a

export dateMax = (a, bs...) ->
  for b in bs
    if b.getTime() > a.getTime()
      a = b
  a
