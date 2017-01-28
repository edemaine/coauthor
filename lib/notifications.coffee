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

  @sortedMessageSubscribers = (group) ->
    _.sortBy messageSubscribers(group), userSortKey

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
        subs = subscribers: (user.username for user in serverMessageSubscribers root when _.some user.emails, (email) -> email.verified)
        if init
          @added 'messages.subscribers', root, subs
        else
          @changed 'messages.subscribers', root, subs
      init = false
    @ready()

  notifiers = {}

  @notifyMessageUpdate = (diff, created = false) ->
    msg = Messages.findOne diff.id
    for to in serverMessageSubscribers msg
      ## Don't send notifications to myself, if so requested.
      continue if diff.updators.length == 1 and diff.updators[0] == to.username and not notifySelf to
      ## Only notify people who can read the message!
      ## Checked again during notification.
      ## xxx this is already checked by serverMessageSubscribers
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
        ## Assuming we don't need to check `created` here, as message existed.
      else
        notification =
          type: 'messageUpdate'
          to: to.username
          message: diff.id
          dates: [diff.updated]
          diffs: [diff._id]
        if created
          notification.created = created
        notificationInsert notification

  @serverMessageSubscribers = (msg) ->
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
    #url = Meteor.absoluteUrl "#{group}"
    url = urlFor 'group',
      group: group
    if html
      "<A HREF=\"#{url}\">#{group}</A>"
    else
      "#{group} [#{url}]"

  linkToMessage = (msg, html, quote = false) ->
    #url = Meteor.absoluteUrl "#{msg.group}/m/#{msg._id}"
    url = urlFor 'message',
      group: msg.group
      message: msg._id
    if html
      if quote
        """&ldquo;<a href=\"#{url}\">#{formatTitleOrFilename msg}</a>&rdquo;"""
      else
        #"<A HREF=\"#{url}\">#{_.escape titleOrUntitled msg}</A>"
        """<a href=\"#{url}\">#{formatTitleOrFilename msg}</a>"""
    else
      if quote
        """"#{titleOrUntitled msg}" [#{url}]"""
      else
        """#{titleOrUntitled msg} [#{url}]"""

  linkToTag = (group, tag, html) ->
    if html
      url = urlFor 'tag',
        group: group
        tag: tag
      """<a href="#{url}">#{tag}</a>"""
    else
      tag

  linkToTags = (group, tags, html) ->
    (linkToTag(group, tag.key, html) for tag in sortTags tags).join(', ') or '(none)'

  notificationEmail = (notifications) ->
    return unless notifications.length > 0
    user = findUsername notifications[0].to
    emails = (email.address for email in user.emails when email.verified)
    ## If no verified email address, don't send, but still mark notification
    ## read.  (Otherwise, upon verifying, you'd get a ton of email.)
    return unless emails.length > 0

    messageUpdates = (notification for notification in notifications when notification.type =='messageUpdate')
    for notification in messageUpdates
      notification.msg = Messages.findOne notification.message
    ## Some messages may have been superdeleted by now; don't email about them.
    messageUpdates = (notification for notification in messageUpdates when notification.msg?)
    ## Ignore messages that have been hidden from this user since (e.g. deleted)
    messageUpdates = (notification for notification in messageUpdates when canSee notification.msg, false, user)
    ## Don't notify about empty messages (e.g. initial creation without
    ## follow-up) -- wait for content.  xxx should check if diff is version 1!
    messageUpdates = (notification for notification in messageUpdates when not messageEmpty notification.msg)
    return if messageUpdates.length == 0

    html = ''
    text = ''
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
          ## Ignore some initial values during creation of message.
          if notification.created
            delete changed.deleted unless msg.deleted
            delete changed.body unless 0 < msg.body.trim().length
            delete changed.tags unless 0 < _.size msg.tags
            ## Don't notify about title or format change when brand new
            delete changed.title
            delete changed.format
          verb = 'updated'
          verb = 'created' if notification.created
          authors = _.sortBy _.keys(authors), userSortKey
          authorsText = (displayUser user for user in authors).join ', '
          authorsHTML = (linkToAuthor msg.group, user for user in authors).join ', '
          if messageUpdates.length == 1
            subject = "#{authorsText} #{verb} '#{titleOrUntitled msg}' in #{msg.group}"
          #if diffs.length > 1
          #  dates = "between #{diffs[0].updated} and #{diffs[diffs.length-1].updated}"
          #else
          dates = "on #{diffs[diffs.length-1].updated}"
          if msg.root?
            html += "<P><B>#{authorsHTML}</B> #{verb} message #{linkToMessage msg, true, true} in the thread #{linkToMessage rootmsg, true, true} #{dates}"
            text += "#{authorsText} #{verb} message #{linkToMessage msg, false, true} in the thread #{linkToMessage rootmsg, false, true} #{dates}"
          else
            html += "<P><B>#{authorsHTML}</B> #{verb} root message in the thread #{linkToMessage msg, true, true} #{dates}"
            text += "#{authorsText} #{verb} root message in the thread #{linkToMessage msg, false, true} #{dates}"
          html += '\n\n'
          text += '\n\n'
          ## xxx currently no notification of title changed
          ## xxx also could use diff on body
          if changed.body
            body = formatBody msg.format, msg.body, true
            html += "<BLOCKQUOTE>\n#{body}\n</BLOCKQUOTE>"
            text += indentLines(msg.body, '    ')
            html += '\n'
            text += '\n'
          if changed.title or changed.deleted or changed.format or changed.tags or changed.file
            html += "<UL>\n"
            if changed.title
              text += "  * Title changed\n"
              html += "<LI>Title changed\n"
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
              text += "  * Tags: #{linkToTags msg.group, msg.tags, false}\n"
              html += "<LI>Tags: #{linkToTags msg.group, msg.tags, true}\n"
            if changed.file
              file = findFile msg.file
              if file?
                text += """  * File upload: "#{file.filename}" (#{file.length} bytes)\n"""
                html += "<LI>File upload: &ldquo;#{file.filename}&rdquo; (#{file.length} bytes)\n"
              else
                text += "  * File upload: #{msg.file}?\n"
                html += "<LI>File upload: #{msg.file}?\n"
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
