@Notifications = new Mongo.Collection 'notifications'

@notificationLevels = [
  'batched'
  'settled'
  'instant'
]

@defaultNotificationDelays =
  batched:
    every: 4
    unit: 'hour'  ## 'hour' or 'day'
    start: 4  ## hour of day to start batches, or hour to do one report if unit == 'day'
  settled:
    settle: 30
    maximum: 60
    unit: 'minute'  ## 'second' or 'minute' or 'hour' or 'day'
  instant:
    settle: 30
    maximum: 30
    unit: 'second'
  #OR: 'instant' has no delays, but 'settled' also applies

timeOffset = (date, amount, unit) ->
  switch unit
    when 'second'
      date.setUTCSeconds date.getUTCSeconds()
    when 'minute'
      date.setUTCMinutes date.getUTCMinutes()
    when 'hour'
      date.setUTCHours date.getUTCHours()
    when 'day'
      date.setUTCDay date.getUTCDay()

## Notification consists of
##   - target: username to notify
##   - level: one of notificationLevels ('batched', 'settled', or 'instant')
##   - first: Date of first update
##   - last: Date of last update
##   - type: 'message'
##     - message: ID of relevant message
##     - diffs: list of IDs of MessageDiffs, starting with null if creation
##   - possible future types: 'import', 'superdelete', 'users', 'settings'
##   - seen: true/false (whether notification has been delivered/deleted)

if Meteor.isServer
  Meteor.publish 'notifications', () ->
    @autorun ->
      user = findUser @userId
      if user?
        Notifications.find
          user: user.username
          seen: false
      else
        @ready()
  Meteor.publish 'notifications.all', () ->
    @autorun ->
      user = findUser @userId
      if user?
        Notifications.find
          user: user.username
      else
        @ready()

  Notifications.find
    seen: false
  .forEach (note) ->
    ## xxx schedule
    console.log 'Scheduling notification', note

  @notificationInsert = (notification) ->
    notification.seen = false
    Notifications.insert notification
    xxx notificationTime notification

@notificationTime = (notification) ->
  user = findUsername notification.target
  delays = user.profile?.notifications?[notification.level] ?
           defaultNotificationDelays[notification.level]
  xxx batched
  settleTime = timeOffset notification.lastUpdate, delays.settle, delays.unit
  maximumTime = timeOffset notification.firstUpdate, delays.maximum, delays.unit
  if settleTime.getTime() < maximumTime.getTime()
    settleTime
  else
    maximumTime
