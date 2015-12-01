Template.layout.helpers
  group: routeGroup  ## should this be renamed to routeGroup, and global?
  groups: -> Groups.find()
  activeGroup: ->
    data = Template.parentData()
    if routeGroup() == @name
      'active'
    else
      ''
