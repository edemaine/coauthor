@Notifications = new Mongo.Collection 'notifications'

@notificationLevels = [
  'batched'
  'settled'
  'instant'
]

@units = ['second', 'minute', 'hour', 'day']

@defaultNotificationDelays =
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

@notificationTime = (notification) ->
  user = findUsername notification.to
  notification.level = 'settled'
  delays = user.profile?.notifications?[notification.level] ?
           defaultNotificationDelays[notification.level]
  #xxx batched
  settleTime = moment(dateMax(notification.dates...)).add(delays.settle, delays.unit).toDate()
  maximumTime = moment(dateMin(notification.dates...)).add(delays.maximum, delays.unit).toDate()
  dateMin settleTime, maximumTime

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
      ## Don't send notifications to myself.  xxx make this an option?
      continue if diff.updators.length == 1 and diff.updators[0] == to.username
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
    if msg.root?
      root = Messages.findOne msg.root
    else
      root = msg
    ## xxx root message should have a field with listen/don't listen flags
    if defaultNotificationsOn
      Meteor.users.find
        'profile.notifications.on': $ne: false
      .fetch()
    else
      Meteor.users.find
        'profile.notifications.on': true
      .fetch()

  notificationInsert = (notification) ->
    notification.seen = false
    notification._id = Notifications.insert notification
    notificationSchedule notification

  notificationUpdate = (old, update) ->
    Meteor.clearTimeout notifiers[old._id]
    Notifications.update old._id, update
    notificationSchedule old._id

  notificationSchedule = (notification) ->
    notification = Notifications.findOne notification unless notification._id?
    time = notificationTime notification
    now = new Date()
    if time.getTime() > now.getTime()
      #console.log notification, '@', time.getTime() - now.getTime()
      notifiers[notification._id] = Meteor.setTimeout ->
        notificationDo notification._id
      , time.getTime() - now.getTime()
    else
      notificationDo notification, false

  notificationDo = (notification, check = true) ->
    notification = Notifications.findOne notification unless notification._id?
    if not check or notificationTime(notification).getTime() >= new Date().getTime()
      notificationEmail notification
      Notifications.update notification._id,
        $set: seen: true
    else
      notificationSchedule notification

  linkToMessage = (msg, html) ->
    url = Meteor.absoluteUrl "#{msg.group}/m/#{msg._id}"
    if html
      "'<A HREF=\"#{url}\">#{titleOrUntitled msg.title}</A>'"
    else
      "'#{titleOrUntitled msg.title}' [#{url}]"

  notificationEmail = (notification) ->
    user = findUsername notification.to
    emails = (email.address for email in user.emails when email.verified)
    ## If no verified email address, don't send, but still mark notification
    ## read.  (Otherwise, upon verifying, you'd get a ton of email.)
    return unless emails.length > 0
    switch notification.type
      when 'messageUpdate'
        msg = Messages.findOne notification.message
        diffs = (MessagesDiff.findOne diff for diff in notification.diffs)
        authors = {}
        for diff in diffs
          for author in diff.updators
            authors[author] = (authors[author] ? 0) + 1
        authors = _.keys(authors).sort().join ', '
        subject = "#{authors} updated '#{titleOrUntitled msg.title}'"
        if msg.root?
          root = Messages.findOne msg.root
          html = "<P><B>#{authors}</B> changed message #{linkToMessage msg, true} in the thread #{linkToMessage root, true}"
          text = "#{authors} changed message #{linkToMessage msg, false} in the thread #{linkToMessage root, false}"
        else
          html = "<P><B>#{authors}</B> changed root message in the thread #{linkToMessage msg, true}"
          text = "#{authors} changed root message in the thread #{linkToMessage msg, false}"
        html += '\n\n'
        text += '\n\n'
        body = formatBody msg.format, msg.body
        html += "<BLOCKQUOTE>\n#{body}\n</BLOCKQUOTE>"
        text += indentLines(stripHTMLTags(body), '    ')
        html += '\n\n'
        text += '\n\n'
        if diffs.length > 1
          dates = "Changes occurred between #{diffs[0].updated} and #{diffs[diffs.length-1].updated}"
        else
          dates = "Change occurred on #{diffs[0].updated}"
        html += "<P><I>#{dates}</I></P>\n"
        text += "#{dates}\n"

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
