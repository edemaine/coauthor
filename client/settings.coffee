Template.settings.helpers
  profile: -> Meteor.user().profile

Template.settings.events
  'click .editorFormat': (e, t) ->
    e.preventDefault()
    Meteor.users.update Meteor.userId(),
      $set: "profile.format": e.target.getAttribute 'data-format'
