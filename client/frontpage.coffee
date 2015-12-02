Template.frontpage.helpers
  groups: ->
    Groups.find()
  groupcount: ->
    Groups.find().count()
