@setTitle = (thing) ->
  if thing?
    title = thing + " - "
  else
    title = ""
  title += routeGroup() + " - Coauthor"
  document.title = title
