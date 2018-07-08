import { defaultFormat } from '../lib/settings.coffee'

Template.registerHelper 'defaultFormat', ->
  defaultFormat

Template.settings.onCreated ->
  @autorun ->
    setTitle 'Settings'

myAfter = (user) -> user.notifications?.after ? defaultNotificationDelays.after

Template.settings.helpers
  profile: -> Meteor.user().profile
  autopublish: autopublish
  notificationsOn: notificationsOn
  notificationsDefault: notificationsDefault
  notificationsSeparate: notificationsSeparate
  notificationsAfter: ->
    after = myAfter @
    "#{after.after} #{after.unit}#{if after.after == 1 then '' else 's'}"
  activeNotificationAfter: (match) ->
    match = match.hash
    after = myAfter @
    if after.after == match.after and after.unit == match.unit
      'active'
    else
      ''
  notifySelf: notifySelf
  autosubscribeGroup: -> autosubscribe routeGroup()
  autosubscribeGlobal: -> autosubscribe wildGroup
  theme: -> capitalize theme()
  previewOn: -> messagePreviewDefault().on
  previewSideBySide: -> messagePreviewDefault().sideBySide
  dropbox: ->
    'dropbox' of (Meteor.user().services ? {})

Template.settings.events
  'click .editorKeyboard': (e, t) ->
    e.preventDefault()
    e.stopPropagation()
    Meteor.users.update Meteor.userId(),
      $set: "profile.keyboard": e.target.getAttribute 'data-keyboard'
    dropdownToggle e

  'click .editorFormat': (e, t) ->
    e.preventDefault()
    e.stopPropagation()
    Meteor.users.update Meteor.userId(),
      $set: "profile.format": e.target.getAttribute 'data-format'
    dropdownToggle e

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

  'click .notificationsSeparateButton': (e, t) ->
    e.preventDefault()
    e.stopPropagation()
    Meteor.users.update Meteor.userId(),
      $set: "profile.notifications.separate": not notificationsSeparate()

  'click .notifySelfButton': (e, t) ->
    e.preventDefault()
    e.stopPropagation()
    Meteor.users.update Meteor.userId(),
      $set: "profile.notifications.self": not notifySelf()

  'click .notificationAfter': (e, t) ->
    e.preventDefault()
    e.stopPropagation()
    Meteor.users.update Meteor.userId(),
      $set: "profile.notifications.after":
        after: parseFloat e.target.getAttribute 'data-after'
        unit: e.target.getAttribute 'data-unit'
    dropdownToggle e

  'click .autosubscribeGlobalButton': (e, t) ->
    e.preventDefault()
    e.stopPropagation()
    Meteor.users.update Meteor.userId(),
      $set: "profile.notifications.autosubscribe.#{wildGroup}": not autosubscribe wildGroup

  'click .autosubscribeGroupButton': (e, t) ->
    e.preventDefault()
    e.stopPropagation()
    Meteor.users.update Meteor.userId(),
      $set: "profile.notifications.autosubscribe.#{escapeGroup routeGroup()}": not autosubscribe routeGroup()

  'click .themeButton': (e, t) ->
    e.preventDefault()
    e.stopPropagation()
    Meteor.users.update Meteor.userId(),
      $set: "profile.theme":
        if theme() == 'dark'
          'light'
        else
          'dark'

  'click .previewButton': (e, t) ->
    e.preventDefault()
    e.stopPropagation()
    Meteor.users.update Meteor.userId(),
      $set: "profile.preview.on":
        not messagePreviewDefault().on

  'click .sideBySideButton': (e, t) ->
    e.preventDefault()
    e.stopPropagation()
    Meteor.users.update Meteor.userId(),
      $set: "profile.preview.sideBySide":
        not messagePreviewDefault().sideBySide

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

timezones = []
#timezoneSource = new Bloodhound
#  datumTokenizer: Bloodhound.tokenizers.whitespace
#  queryTokenizer: Bloodhound.tokenizers.whitespace
#  #prefetch: '/timezones.json'
#  #local: timezones
timezoneSource = (q, callback) ->
  re = new RegExp (escapeRegExp q).replace(/[ _]/g, '[ _]'), 'i'
  callback(timezone for timezone in timezones when timezone.match re)

Template.timezoneSelector.onCreated ->
  Meteor.http.get '/timezones.json', (error, result) ->
    return console.error "Failed to load timezones: #{error}" if error
    timezones = JSON.parse result.content
    console.log "Loaded #{timezones.length} timezones."

Template.timezoneSelector.onRendered ->
  $('.typeahead').typeahead
    hint: true
    highlight: true
    minLength: 1
  ,
    name: 'timezones'
    limit: 50
    source: timezoneSource
    templates: notFound: '<i style="margin: 0ex 1em">No matching timezones found.</i>'
  ## Update disabled state now and whenever profile changes
  @autorun => timezoneEdit null, @

timezoneValid = (zone) ->
  #canon = timezoneCanon zone
  #return true if zone == ''
  #_.any (canon == timezoneCanon goodZone for goodZone in timezones)
  zone == '' or _.contains timezones, zone

timezoneEdit = (e, t) ->
  e.preventDefault() if e?
  e.stopPropagation() if e?
  zone = t.find('.tt-input').value
  enable = Template.currentData().timezone != zone and timezoneValid zone
  t.$('.saveButton').attr 'disabled', not enable

Template.timezoneSelector.events
  'input .timezone': timezoneEdit
  'typeahead:autocomplete .timezone': timezoneEdit
  'typeahead:cursorchange .timezone': timezoneEdit
  'typeahead:select .timezone': (e, t) ->
    timezoneEdit e, t
    unless t.$('.saveButton').attr 'disabled'
      timezoneSave e, t

  'click .saveButton': timezoneSave = (e, t) ->
    e.preventDefault()
    e.stopPropagation()
    zone = t.find('.tt-input').value
    return unless timezoneValid zone
    #t.$('.tt-input').typeahead 'val', zone
    Meteor.users.update Meteor.userId(),
      $set: "profile.timezone": zone
    #, -> Meteor.defer -> timezoneEdit e, t
