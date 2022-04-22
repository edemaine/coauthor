import {Mongo} from 'meteor/mongo'

import {profiling} from './profiling'

@Notifications = new Mongo.Collection 'notifications'

if Meteor.isServer
  Notifications.createIndex [['seen', 1], ['to', 1], ['message', 1]]

###
export notificationLevels = [
  'batched'
  'settled'
  'instant'
]

export units = ['second', 'minute', 'hour', 'day']
###

export defaultNotificationDelays =
  after:
    after: 1
    unit: 'hour'
  ## None of the following actually do anything yet:
  ###
  batched:
    every: 4
    unit: 'hour'  ## 'hour' or 'day'
    start: 4  ## hour of day to start batches, or hour to do one report if unit == 'day'
  settled:
    settle: 10
    maximum: 60
    unit: 'minute'  ## 'second' or 'minute' or 'hour' or 'day'
  instant:
    settle: 30
    maximum: 30
    unit: 'second'
  ###
  #OR: 'instant' has no delays, but 'settled' also applies

export defaultNotificationsOn = true

export notificationsDefault = ->
  not Meteor.user().profile.notifications?.on?

export notificationsOn = ->
  if notificationsDefault()
    defaultNotificationsOn
  else
    Meteor.user().profile.notifications.on

export notificationsSeparate = (user = Meteor.user()) ->
  user.profile.notifications?.separate

export notifySelf = (user = Meteor.user()) ->
  #user = findUser user if _.isString user
  user.profile.notifications?.self

#export autosubscribeGroup = (group, user = Meteor.user()) ->
#  user.profile?.notifications?.autosubscribe?[escapeGroup group] != false

export autosubscribe = (group, user = Meteor.user()) ->
  ###
  Return whether the user is autosubscribed to the specified group.
  If the user hasn't specified whether they are autosubscribed to that group,
  the default is whether they are globally autosubscribed, and if that
  hasn't been specified either, the default is true.
  ###
  auto = user?.profile?.notifications?.autosubscribe
  if auto?
    (auto[escapeGroup group] ? auto[wildGroup]) != false
  else
    true

## Checks whether specified user has *requested* notifications about this
## message, as desired by client checkbox UI.  It therefore does *not* check
## two conditions required for notifications:
## * memberOfGroup.  On client, this should be implied by view.
## * canSee.  On client, this is implied when user = self.
##   When generating notification list, we're interested generally about the
##   thread, so this is a good approximation.
## * The user has a verified email address.  Don't want this for client
##   checkboxes.
export subscribedToMessage = (message, user = Meteor.user()) ->
  message = findMessage message
  root = message.root ? message._id
  #canSee(message, false, user) and \
  #memberOfGroup(message.group, user) and \
  if autosubscribe message.group, user
    root not in (user?.profile?.notifications?.unsubscribed ? [])
  else
    root in (user?.profile?.notifications?.subscribed ? [])

## Mimicks logic of subscribedToMessage above, plus requires group membership,
## verified email, and canSee (everything required for notifications).
## memberOfGroup test prevents users with global permissions from
## autosubscribing to everything.  Also easier to find subscribers
## by starting with group's members.
messageSubscribers = (msg, options = {}) ->
  msg = findMessage msg
  return [] unless msg?
  group = findGroup msg.group
  if options.fields?
    options.fields.roles = true
    options.fields.rolesPartial = true
    options.fields['profile.notifications'] = true
  users = Meteor.users.find
    username: $in: groupMembers group
    emails: $elemMatch: verified: true
    'profile.notifications.on':
      if defaultNotificationsOn
        $ne: false
      else
        true
  , options
  .fetch()
  for user in users
    continue unless subscribedToMessage msg, user
    continue unless canSee msg, false, user, group
    continue unless fullMemberOfGroup(group, user) or memberOfThread(msg, user)
    user
export messageSubscribers =
  profiling 'notifications.messageSubscribers', messageSubscribers

export sortedMessageSubscribers = (msg, options = {}) ->
  if options.fields?
    options.fields.username = true
    options.fields['profile.fullname'] = true  ## for sorting by fullname
  users = messageSubscribers msg, options
  _.sortBy users, userSortKey
