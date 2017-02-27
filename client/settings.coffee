Template.settings.onCreated ->
  @autorun ->
    setTitle 'Settings'

Template.settings.helpers
  profile: -> Meteor.user().profile
  autopublish: autopublish
  notificationsOn: notificationsOn
  notificationsDefault: notificationsDefault
  notifySelf: notifySelf
  autosubscribeGroup: -> autosubscribeGroup routeGroup()
  autosubscribeGlobal: -> autosubscribeGroup wildGroup
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

  'click .autosubscribeGlobalButton': (e, t) ->
    e.preventDefault()
    e.stopPropagation()
    Meteor.users.update Meteor.userId(),
      $set: "profile.notifications.autosubscribe.#{wildGroup}": not autosubscribeGroup wildGroup

  'click .autosubscribeGroupButton': (e, t) ->
    e.preventDefault()
    e.stopPropagation()
    Meteor.users.update Meteor.userId(),
      $set: "profile.notifications.autosubscribe.#{escapeGroup routeGroup()}": not autosubscribeGroup routeGroup()

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

for template in [Template.fullNameEditor, Template.emailEditor]
  template.onCreated ->
    @editing = new ReactiveVar
    ## When active editor gets rendered (typically after clicking "Edit"),
    ## give it focus.
    @autorun =>
      if @editing.get()
        setTimeout =>
          $(@find '.textEdit').focus()
        , 100
  template.helpers
    editing: -> Template.instance().editing.get()
  template.events
    'click .editButton': (e, t) ->
      e.preventDefault()
      e.stopPropagation()
      t.editing.set true
  saveButton = (callback) -> (e, t) ->
    e.preventDefault()
    e.stopPropagation()
    value = t.find('.textEdit').value.trim()
    callback.call @, value
    t.editing.set false

Template.fullNameEditor.helpers
  fullname: -> @fullname
  showFullname: -> @fullname or "(not specified)"

Template.fullNameEditor.events
  'click .saveButton': saveButton (fullname) ->
    if fullname != @fullname
      Meteor.users.update Meteor.userId(),
        $set: 'profile.fullname': fullname

currentEmail = ->
  Meteor.user().emails?[0]?.address

Template.emailEditor.helpers
  email: currentEmail
  showEmail: -> currentEmail() or "(not specified)"

Template.emailEditor.events
  'click .saveButton': saveButton (email) ->
    if email != currentEmail()
      Meteor.call 'userEditEmail', email
