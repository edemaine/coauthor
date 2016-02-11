@Notifications = new Mongo.Collection 'notifications'

@notificationLevels = [
  'batched'
  'settled'
  'instant'
]

@defaultNotificationDelays =
  batched:
    every: 4
    offset: 4
    unit: 'hour'
  settled:
    settle: 30
    maximum: 60
    unit: 'minute'
  instant:
    settle: 5
    maximum: 5
    unit: 'second'
  #OR: 'instant' has no delays, but 'settled' also applies

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
  
