@capitalize = (x) ->
  return x unless x?
  if x == 'html'
    'HTML'
  else if x == 'latex'
    'LaTeX'
  else
    x.charAt(0).toUpperCase() + x.slice(1).toLowerCase()

Template?.registerHelper 'capitalize', capitalize
