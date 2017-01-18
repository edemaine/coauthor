@Notifications = new Mongo.Collection 'notifications'

@notificationLevels = [
  'batched'
  'settled'
  'instant'
]

@units = ['second', 'minute', 'hour', 'day']

@defaultNotificationDelays =
  after:
    after: 1
    unit: 'hour'
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
  #OR: 'instant' has no delays, but 'settled' also applies

@defaultNotificationsOn = true

@notificationsDefault = ->
  not Meteor.user().profile.notifications?.on?

@notificationsOn = ->
  if notificationsDefault()
    defaultNotificationsOn
  else
    Meteor.user().profile.notifications.on

@notifySelf = (user = Meteor.user()) ->
  #user = findUser user if _.isString user
  user.profile.notifications?.self

@autosubscribe = (user = Meteor.user()) ->
  not user.profile.notifications? or user.profile.notifications?.autosubscribe != false

@subscribedToMessage = (message, user = Meteor.user()) ->
  canSee(message, false, user) and \
  if message in (user.profile.notifications?.subscribed ? [])
    true
  else if message in (user.profile.notifications?.unsubscribed ? [])
    false
  else
    autosubscribe user

@notificationTime = (notification) ->
  user = findUsername notification.to
  notification.level = 'after'
  delays = user.profile?.notifications?[notification.level] ?
           defaultNotificationDelays[notification.level]
  moment(dateMin(notification.dates...)).add(delays.after, delays.unit).toDate()
  ## Old settle dynamics:
  #settleTime = moment(dateMax(notification.dates...)).add(delays.settle, delays.unit).toDate()
  #maximumTime = moment(dateMin(notification.dates...)).add(delays.maximum, delays.unit).toDate()
  #dateMin settleTime, maximumTime

## Notification consists of
##   - to: username to notify
##   - level: one of notificationLevels ('batched', 'settled', or 'instant')
##   - dates: list of Dates of updates
##   - type: 'messageUpdate'
##     - message: ID of relevant message
##     - diffs: list of IDs of MessagesDiff (in bijection with dates list)
##   - possible future types: 'import', 'superdelete', 'users', 'settings'
##   - seen: true/false (whether notification has been delivered/deleted)

if Meteor.isClient
  @MessagesSubscribers = new Mongo.Collection 'messages.subscribers'

  @messageSubscribers = (msg) ->
    unless _.isString msg
      msg = msg._id
    MessagesSubscribers.findOne(msg)?.subscribers ? []

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

  Meteor.publish 'messages.subscribers', (root) ->
    check root, String
    if canSee root, false, findUser @userId
      init = true
      @autorun ->
        subs = subscribers: (user.username for user in messageSubscribers root when _.some user.emails, (email) -> email.verified)
        if init
          @added 'messages.subscribers', root, subs
        else
          @changed 'messages.subscribers', root, subs
      init = false
    @ready()

  notifiers = {}

  @notifyMessageUpdate = (diff) ->
    msg = Messages.findOne diff.id
    ## Don't notify about empty messages (e.g. initial creation) --
    ## wait for content.  xxx should only do this if diff is version 1!
    return if messageEmpty msg
    for to in messageSubscribers msg
      ## Don't send notifications to myself, if so requested.
      continue if diff.updators.length == 1 and diff.updators[0] == to.username and not notifySelf to
      ## Only notify people who can read the message!
      ## xxx this is already checked by messageSubscribers
      ## xxx what should behavior be for superuser?  Currently they see all...
      continue unless canSee msg, false, to
      ## Coallesce past notification (if it exists) into this notification,
      ## if they regard the same message and haven't yet been seen by user.
      notification = Notifications.findOne
        type: 'messageUpdate'
        to: to.username
        message: diff.id
        seen: false
      if notification?
        notificationUpdate notification,
          $push:
            dates: diff.updated
            diffs: diff._id
      else
        notificationInsert
          type: 'messageUpdate'
          to: to.username
          message: diff.id
          dates: [diff.updated]
          diffs: [diff._id]

  messageSubscribers = (msg) ->
    if _.isString msg
      root = msg
    else
      root = msg.root ? msg._id
    users = Meteor.users.find
      'profile.notifications.on':
        if defaultNotificationsOn
          $ne: false
        else
          true
      ## This query didn't work ($ne doesn't enter array elements?)
      #$or: [
      #  autosubscribe: $ne: false
      #  unsubscribe: $ne: root
      #,
      #  autosubscribe: false
      #  subscribe: root
      #]
    .fetch()
    user for user in users when subscribedToMessage root, user

  notificationInsert = (notification) ->
    notification.seen = false
    notification._id = Notifications.insert notification
    notificationSchedule notification

  notificationUpdate = (old, update) ->
    Notifications.update old._id, update
    notificationSchedule old._id

  ## Don't schedule anything sooner than one second from now.
  ## This is useful when many things are trying to schedule for right now
  ## (as in a server start with many expired messages), and we only want one
  ## to succeed.  This one-second delay lets them all clobber each other
  ## except the last one.  There Can Be Only One.
  minSchedule = 1000

  notificationSchedule = (notification) ->
    notification = Notifications.findOne notification unless notification._id?
    time = notificationTime notification
    ## If a batch notification is already scheduled earlier than this one
    ## would be, then that will cover this notification, so we don't need to
    ## schedule anything new.  But if this notification is more urgent (this
    ## will happen when server starts with expired messages, for example),
    ## we should reschedule.  Finally, if a notification is already running,
    ## we also don't need to do anything, because at the end of running the
    ## notifier will check for any new notifications to schedule.
    if notification.to of notifiers
      if notifiers[notification.to].running or notifiers[notification.to].time.getTime() <= time.getTime()
        return
      else
        Meteor.clearTimeout notifiers[notification.to].timeout
    now = new Date()
    #console.log notification, '@', time.getTime() - now.getTime()
    notifiers[notification.to] =
      time: time
      timeout:
        Meteor.setTimeout ->
          notificationDo notification.to
        , Math.max(minSchedule, time.getTime() - now.getTime())

  notificationDo = (to) ->
    ## During this callback, prevent other notifications from scheduling.
    notifiers[to].running = true
    Meteor.clearTimeout notifiers[to].timeout
    notifications = Notifications.find
      to: to
      seen: false
    .fetch()
    notificationEmail notifications
    Notifications.update
      _id: $in: (notification._id for notification in notifications)
    ,
      $set: seen: true
    ,
      multi: true
    ## Now we relinquish the 'lock' set by notifiers[to].
    delete notifiers[to]
    ## In the meantime, new notifications may have appeared; schedule them.
    Notifications.find
      to: to
      seen: false
    .forEach (notification) ->
      notificationSchedule notification

  linkToGroup = (group, html) ->
    url = Meteor.absoluteUrl "#{group}"
    if html
      "<A HREF=\"#{url}\">#{group}</A>"
    else
      "#{group} [#{url}]"

  linkToMessage = (msg, html) ->
    url = Meteor.absoluteUrl "#{msg.group}/m/#{msg._id}"
    if html
      "<A HREF=\"#{url}\">#{_.escape titleOrUntitled msg.title}</A>"
    else
      "#{titleOrUntitled msg.title} [#{url}]"

  notificationEmail = (notifications) ->
    return unless notifications.length > 0
    user = findUsername notifications[0].to
    emails = (email.address for email in user.emails when email.verified)
    ## If no verified email address, don't send, but still mark notification
    ## read.  (Otherwise, upon verifying, you'd get a ton of email.)
    return unless emails.length > 0

    html = ''
    text = ''
    messageUpdates = (notification for notification in notifications when notification.type =='messageUpdate')
    for notification in messageUpdates
      notification.msg = Messages.findOne notification.message
    ## Some messages may have been superdeleted by now; don't email about them.
    messageUpdates = (notification for notification in notifications when notification.msg?)
    return if messageUpdates.length == 0
    bygroup = _.groupBy messageUpdates, (notification) -> notification.msg.group
    if messageUpdates.length != 1
      subject = "#{messageUpdates.length} updates in #{_.keys(bygroup).sort().join ', '}"
    bygroup = _.pairs bygroup
    bygroup = _.sortBy bygroup, (pair) -> pair[0]
    for [group, groupUpdates] in bygroup
      bythread = _.groupBy groupUpdates,
        (notification) -> notification.msg.root ? notification.msg._id
      bythread = _.pairs bythread
      for pair in bythread
        pair.push Messages.findOne pair[0]  ## root id -> root msg
      bythread = _.sortBy bythread, (triple) -> titleSort triple[2].title  ## root msg title
      html += "<H1>#{linkToGroup group, true}: #{pluralize groupUpdates.length, 'update'} in #{pluralize bythread.length, 'thread'}</H1>\n\n"
      text += "=== #{group}: #{pluralize groupUpdates.length, 'update'} in #{pluralize bythread.length, 'thread'} ===\n\n"
      for [root, rootUpdates, rootmsg] in bythread
        html += "<H2>#{linkToMessage rootmsg, true}</H2>\n\n"
        text += "--- #{linkToMessage rootmsg, false} ---\n\n"
        rootUpdates = _.sortBy rootUpdates, (notification) ->
          if notification.msg.root?
            dateMin(notification.dates...).getTime()
          else
            0  ## put root at top
        for notification in rootUpdates
          msg = notification.msg
          diffs = (MessagesDiff.findOne diff for diff in notification.diffs)
          authors = {}
          changed = {}
          for diff in diffs
            for author in diff.updators
              authors[author] = (authors[author] ? 0) + 1
            for key of diff
              changed[key] = true
          authors = _.keys(authors).sort().join ', '
          if messageUpdates.length == 1
            subject = "#{authors} updated '#{titleOrUntitled msg.title}' in #{msg.group}"
          #if diffs.length > 1
          #  dates = "between #{diffs[0].updated} and #{diffs[diffs.length-1].updated}"
          #else
          dates = "on #{diffs[diffs.length-1].updated}"
          if msg.root?
            html += "<P><B>#{authors}</B> changed message '#{linkToMessage msg, true}' in the thread '#{linkToMessage rootmsg, true}' #{dates}"
            text += "#{authors} changed message '#{linkToMessage msg, false}' in the thread '#{linkToMessage rootmsg, false}' #{dates}"
          else
            html += "<P><B>#{authors}</B> changed root message in the thread #{linkToMessage msg, true} #{dates}"
            text += "#{authors} changed root message in the thread #{linkToMessage msg, false} #{dates}"
          html += '\n\n'
          text += '\n\n'
          ## xxx currently no notification of title changed
          ## xxx also could use diff on body
          if changed.body
            body = formatBody msg.format, msg.body, true
            html += "<BLOCKQUOTE>\n#{body}\n</BLOCKQUOTE>"
            text += indentLines(stripHTMLTags(body), '    ')
            html += '\n'
            text += '\n'
          if changed.deleted or changed.format or changed.tags
            html += "<UL>\n"
          if changed.deleted
            if msg.deleted
              text += "  * DELETED\n"
              html += "<LI>DELETED\n"
            else
              text += "  * UNDELETED\n"
              html += "<LI>UNDELETED\n"
          if changed.format
            text += "  * Format: #{msg.format}\n"
            html += "<LI>Format: #{msg.format}\n"
          if changed.tags
            text += "  * Tags: #{_.keys(sortTags msg.tags).join ", "}\n"
            html += "<LI>Tags: #{_.keys(sortTags msg.tags).join ", "}\n"
          if changed.format or changed.tags
            html += "</UL>\n"
          html += '\n'
          text += '\n'

    Email.send
      from: Accounts.emailTemplates.from
      to: emails
      subject: '[Coauthor] ' + subject
      html: html
      text: text

  ## Reschedule any leftover notifications from last server run.
  Meteor.startup ->
    Notifications.find
      seen: false
    .forEach (notification) ->
      try
        notificationSchedule notification
      catch e
        console.warn 'Could not schedule', notification, ':', e
