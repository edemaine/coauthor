## Upgrade from old file message format (format 'file', body = file pointer)
## to new file message format (file = file pointer)
Messages.find
  format: 'file'
.forEach (msg) ->
  Messages.update msg._id,
    $set:
      format: defaultFormat
      title: ''
      body: ''
      file: msg.body
MessagesDiff.find
  format: 'file'
.forEach (diff) ->
  MessagesDiff.update diff._id,
    $set:
      format: defaultFormat
      title: ''
      body: ''
      file: diff.body

## Upgrade from old autosubscribe profile setting format
Meteor.users.update
  'profile.notifications.autosubscribe': true
,
  $set: 'profile.notifications.autosubscribe': {"#{wildGroup}": true}
,
  multi: true
Meteor.users.update
  'profile.notifications.autosubscribe': false
,
  $set: 'profile.notifications.autosubscribe': {"#{wildGroup}": false}
,
  multi: true

## Upgrade from old notification format which listed all dates and diffs
Notifications.find
  dates: $exists: true
.forEach (notification) ->
  Notifications.update notification._id,
    $set:
      dateMin: dateMin(notification.dates...)
      dateMax: dateMax(notification.dates...)
    $unset:
      dates: ''
      ## leaving diffs for posterity
      ## not creating old/new for now... could be built from dateMin/dateMax

## Upgrade from old notification format which lacked group field
Notifications.find
  group: $exists: false
  message: $exists: true
.forEach (notification) ->
  Notifications.update notification._id,
    $set:
      group: message2group notification.message

console.log 'Upgraded database as necessary.'
