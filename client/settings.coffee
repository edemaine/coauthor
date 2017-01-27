Template.settings.onCreated ->
  @autorun ->
    setTitle 'Settings'

Template.settings.helpers
  profile: -> Meteor.user().profile
  autopublish: autopublish
  notificationsOn: notificationsOn
  notificationsDefault: notificationsDefault
  notifySelf: notifySelf
  autosubscribe: autosubscribe
  theme: -> capitalize theme()
  dropbox: ->
    'dropbox' of (Meteor.user().services ? {})

Template.settings.events
  'click .editorFormat': (e, t) ->
    e.preventDefault()
    e.stopPropagation()
    Meteor.users.update Meteor.userId(),
      $set: "profile.format": e.target.getAttribute 'data-format'

  'click .autopublishButton': (e, t) ->
    e.preventDefault()
    e.stopPropagation()
    Meteor.users.update Meteor.userId(),
      $set: "profile.autopublish": not autopublish()

  'click .notificationsButton': (e, t) ->
    e.preventDefault()
    e.stopPropagation()
    Meteor.users.update Meteor.userId(),
      $set: "profile.notifications.on": not notificationsOn()

  'click .notifySelfButton': (e, t) ->
    e.preventDefault()
    e.stopPropagation()
    Meteor.users.update Meteor.userId(),
      $set: "profile.notifications.self": not notifySelf()

  'click .autosubscribeButton': (e, t) ->
    e.preventDefault()
    e.stopPropagation()
    Meteor.users.update Meteor.userId(),
      $set: "profile.notifications.autosubscribe": not autosubscribe()

  'click .themeButton': (e, t) ->
    e.preventDefault()
    e.stopPropagation()
    Meteor.users.update Meteor.userId(),
      $set: "profile.theme":
        if theme() == 'dark'
          'light'
        else
          'dark'

  'click .linkDropbox': (e, t) ->
    e.preventDefault()
    e.stopPropagation()
    Meteor.linkWithDropbox()

  'click .unlinkDropbox': (e, t) ->
    e.preventDefault()
    e.stopPropagation()
    Meteor.call '_accounts/unlink/service', Meteor.userId(), 'dropbox'

Template.fullNameEditor.onCreated ->
  @editing = new ReactiveVar

Template.fullNameEditor.helpers
  editing: -> Template.instance().editing.get()
  fullname: -> @fullname
  showFullname: -> @fullname or "(not specified)"

Template.fullNameEditor.events
  'click .saveButton': (e, t) ->
    e.stopPropagation()
    fullname = t.find('.fullname').value.trim()
    if fullname != @fullname
      Meteor.users.update Meteor.userId(),
        $set: 'profile.fullname': fullname
    t.editing.set false
  'click .editButton': (e, t) ->
    e.stopPropagation()
    t.editing.set true
