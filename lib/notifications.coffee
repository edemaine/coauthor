@Notifications = new Mongo.Collection 'notifications'

@notificationLevels = [
  'batched'
  'settled'
  'instant'
]

@defaultNotificationDelays =
  batched:
    batch:
      amount: 4
      unit: 'hour'
  settled:
    settle:
      amount: 30
      unit: 'minute'
    maximum:
      amount: 60
      unit: 'minute'
  instant:
    settle:
      amount: 0
      unit: 'second'
    maximum:
      amount: 0
      unit: 'second'

## notification can consist of
##   - level: one of notificationLevels
##   - message: ID of relevant message
##   - updates: list of changed, title, body, ... from message

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
  Meteor.publish 'notifications.old', () ->
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
    notification.when = new Date unless notification.when?
    notification.seen = false
    Notifications.insert notification
    xxx notificationTime notification

@notificationTime = (notification) ->
  notification.when
  user = findUsername notification.username
  delays = user.profile?.notifications?[notification.level]
  
