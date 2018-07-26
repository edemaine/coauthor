## Stores not-yet-committed changes to image settings
@liveImageSettings = new ReactiveDict

settingsDefaults =
  rotate: 0
settingsKeys = _.keys settingsDefaults

changeLiveImageSettings = (id, key, changer) ->
  return unless id?
  settings = liveImageSettings.get(id) ? {}
  old = settings[key] ? settingsDefaults[key]
  settings[key] = changer old
  if key == 'rotate'
    while settings[key] < -180
      settings[key] += 360
    while settings[key] > 180
      settings[key] -= 360
  liveImageSettings.set id, settings

changedLiveImageSettings = (data) ->
  live = liveImageSettings.get data._id
  diff = {}
  for key, value of live
    unless value == (data?[key] ? settingsDefaults[key])
      diff[key] = value
  if _.isEqual diff, {}
    null
  else
    diff

Template.messageImage.onCreated ->
  @autorun =>
    liveImageSettings.delete @id if @id?
    data = Template.currentData()
    @id = data._id
    return unless @id?
    liveImageSettings.set @id, _.pick data ? {}, settingsKeys...

Template.messageImage.onDestroyed ->
  liveImageSettings.delete @id if @id?

Template.messageImage.onRendered ->
  @rotateSlider?.destroy()
  `import('bootstrap-slider')`.then (Slider) =>
    Slider = Slider.default
    @rotateSlider = new Slider @$('.rotateSlider')[0],
      min: -180
      max: 180
      tooltip: 'hide'
      #value: 0  ## doesn't update, unlike setValue method below
      #formatter: (v) -> 
    @autorun =>
      data = Template.currentData()
      @rotateSlider.setValue liveImageSettings.get(data._id).rotate ? settingsDefaults.rotate
  
Template.messageImage.events
  'click a.disabled': (e) ->
    e.preventDefault()
    e.stopPropagation()
  'hide.bs.dropdown .messageImage': (e, t) ->
    if diff = changedLiveImageSettings t.data
      Meteor.call 'messageUpdate', t.data._id, diff
  'change .rotateSlider': (e, t) ->
    changeLiveImageSettings t.data._id, 'rotate', -> e.value.newValue
  'click .rotateZero': (e, t) ->
    changeLiveImageSettings t.data._id, 'rotate', -> 0
  'click .rotateCW90': (e, t) ->
    changeLiveImageSettings t.data._id, 'rotate', (val) -> val += 90
  'click .rotateCCW90': (e, t) ->
    changeLiveImageSettings t.data._id, 'rotate', (val) -> val += -90
  'change .rotateAngle': (e, t) ->
    angle = parseFloat e.target.value
    unless isNaN angle
      changeLiveImageSettings t.data._id, 'rotate', -> angle

Template.messageImage.helpers
  rotate: -> liveImageSettings.get(@_id)?.rotate ? 0
  changedClass: ->
    if changedLiveImageSettings @
      ''
    else
      'disabled'
