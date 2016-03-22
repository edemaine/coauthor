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
    unit: 'minute'
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

  notifiers = {}

  @notifyMessageUpdate = (diff) ->
    msg = Messages.findOne diff.id
    ## Don't notify about empty messages (e.g. initial creation) --
    ## wait for content.  xxx should only do this if diff is version 1!
    return if messageEmpty msg
    for to in messageListeners msg
      ## Don't send notifications to myself, if so requested.
      continue if diff.updators.length == 1 and diff.updators[0] == to.username and not notifySelf to
      ## Only notify people who can read the message!
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

  messageListeners = (msg) ->
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

  notificationSchedule = (notification) ->
    notification = Notifications.findOne notification unless notification._id?
    time = notificationTime notification
    ## If a batch notification is already scheduled earlier than this one
    ## would be, then that will cover this notification, so we don't need to
    ## schedule anything new.  But if this notification is more urgent (this
    ## will happen when server starts with expired messages, for example),
    ## we should reschedule.
    if notification.to of notifiers
      if notifiers[notification.to].time.getTime() <= time.getTime()
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
        , Math.max(0, time.getTime() - now.getTime())

  notificationDo = (to) ->
    Meteor.clearTimeout notifiers[to].timeout
    delete notifiers[to]
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

  linkToGroup = (group, html) ->
    url = Meteor.absoluteUrl "#{group}"
    if html
      "<A HREF=\"#{url}\">#{group}</A>"
    else
      "#{group} [#{url}]"

  linkToMessage = (msg, html) ->
    url = Meteor.absoluteUrl "#{msg.group}/m/#{msg._id}"
    if html
      "'<A HREF=\"#{url}\">#{titleOrUntitled msg.title}</A>'"
    else
      "'#{titleOrUntitled msg.title}' [#{url}]"

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
    bygroup = _.pairs(bygroup).sort()
    for [group, groupUpdates] in bygroup
      bythread = _.groupBy groupUpdates,
        (notification) -> notification.msg.root ? notification.msg._id
      bythread = _.pairs(bythread).sort()
      html += "<H1>#{linkToGroup group, true}: #{pluralize groupUpdates.length, 'update'} in #{pluralize bythread.length, 'thread'}</H1>\n\n"
      text += "=== #{group}: #{pluralize groupUpdates.length, 'update'} in #{pluralize bythread.length, 'thread'} ===\n\n"
      for [root, rootUpdates] in bythread
        rootmsg = Messages.findOne root
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
          for diff in diffs
            for author in diff.updators
              authors[author] = (authors[author] ? 0) + 1
          authors = _.keys(authors).sort().join ', '
          if messageUpdates.length == 1
            subject = "#{authors} updated '#{titleOrUntitled msg.title}' in #{msg.group}"
          #if diffs.length > 1
          #  dates = "between #{diffs[0].updated} and #{diffs[diffs.length-1].updated}"
          #else
          dates = "on #{diffs[diffs.length-1].updated}"
          if msg.root?
            html += "<P><B>#{authors}</B> changed message #{linkToMessage msg, true} in the thread #{linkToMessage rootmsg, true} #{dates}"
            text += "#{authors} changed message #{linkToMessage msg, false} in the thread #{linkToMessage rootmsg, false} #{dates}"
          else
            html += "<P><B>#{authors}</B> changed root message in the thread #{linkToMessage msg, true} #{dates}"
            text += "#{authors} changed root message in the thread #{linkToMessage msg, false} #{dates}"
          html += '\n\n'
          text += '\n\n'
          body = sanitizeHtml formatBody msg.format, msg.body
          html += "<BLOCKQUOTE>\n#{body}\n</BLOCKQUOTE>"
          text += indentLines(stripHTMLTags(body), '    ')
          html += '\n\n'
          text += '\n\n'

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
