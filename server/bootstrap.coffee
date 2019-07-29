import { idleStop } from '../lib/messages.coffee'

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

## Upgrade from old single (editor) theme setting
Meteor.users.find
  'profile.theme': $type: 'string'
.forEach (user) ->
  Meteor.users.update user._id,
    $set: 'profile.theme': editor: user.profile.theme

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

## Retroactively add "finished" indicators for any final diffs and diffs with a
## gap of at least one hour (`idleStop` in `lib/messages.coffee`), if we're
## updating from a code base that didn't record these.
unless MessagesDiff.findOne finished: $exists: true
  finishDiff = (diff) ->
    MessagesDiff.update diff._id,
      $set: finished: diff.updators
  lastDiff = null
  MessagesDiff.find {}
  , sort: [['id', 'asc'], ['updated', 'asc']]
  .forEach (diff) ->
    if diff.id != lastDiff?.id
      finishDiff lastDiff if lastDiff?
      lastDiff = null
    if lastDiff?.updated? and diff.updators? and diff.updated?
      if diff.updated.getTime() - lastDiff.updated.getTime() > idleStop
        #console.log diff.id, diff._id, lastDiff.updated, diff.updated, diff.updated.getTime() - lastDiff.updated.getTime()
        finishDiff lastDiff
    lastDiff = diff
  finishDiff lastDiff if lastDiff?

## This code would add version numbers to MessageDiff objects, instead of
## relying on sorting by 'updated'...  (code not finished)
#if true
#  Messages.find().forEach (msg) ->
#    olds = MessagesDiff.find
#      id: msg._id
#    ,
#      sort: [
#    .fetch()
#    console.log olds

console.log 'Upgraded database as necessary.'
