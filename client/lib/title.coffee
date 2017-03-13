@setTitle = (thing) ->
  title = thing ? ''
  title += ' - ' if thing
  title += routeGroup() ? ''
  title += ' - ' if routeGroup()
  title += "Coauthor"
  document.title = title
