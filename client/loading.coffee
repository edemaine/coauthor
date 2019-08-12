Meteor.Spinner.options.length = 15
Meteor.Spinner.options.radius = 10
Meteor.Spinner.options.width = 5

Template.registerHelper 'ready', ->
  Router.current().ready()
