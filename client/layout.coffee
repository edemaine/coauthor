Template.layout.helpers
  activeGroup: ->
    data = Template.parentData()
    if routeGroup() == @name
      'active'
    else
      ''
