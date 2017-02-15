@Notifications = new Mongo.Collection 'notifications'

if Meteor.isServer
  Notifications._ensureIndex [['to', 1], ['seen', 1], ['message', 1]]

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

## Checks whether specified user has *requested* notifications about this
## message, as desired by client checkbox UI.  It therefore does *not* check
## two conditions required for notifications:
## * canSee.  On client, this is implied when user = self.
##   When generating notification list, we're interested generally about the
##   thread, so this is a good approximation.
## * The user has a verified email address.  Don't want this for client
##   checkboxes.
@subscribedToMessage = (message, user = Meteor.user()) ->
  #canSee(message, false, user) and \
  ## memberOfGroup test prevents users with global permissions from
  ## autosubscribing to everything.  Also easier to find subscribers
  ## by starting with group's members.
  memberOfGroup(message2group(message), user) and \
  if autosubscribe user
    message not in (user.profile.notifications?.unsubscribed ? [])
  else
    message in (user.profile.notifications?.subscribed ? [])

## Mimicks logic of subscribedToMessage above, plus requires verified email
## and canSee (everything required for notifications).
@messageSubscribers = (msg, options = {}) ->
  msg = findMessage msg
  group = msg.group
  root = msg.root ? msg._id
  options.fields.roles = true if options.fields?
  users = Meteor.users.find
    username: $in: groupMembers group
    emails: $elemMatch: verified: true
    'profile.notifications.on':
      if defaultNotificationsOn
        $ne: false
      else
        true
    $or: [
      'profile.notifications.autosubscribe': $ne: false
      'profile.notifications.unsubscribed': $nin: [root]
    ,
      'profile.notifications.autosubscribe': false
      'profile.notifications.subscribed': root
    ]
  , options
  .fetch()
  (user for user in users when canSee msg, false, user)

@sortedMessageSubscribers = (msg) ->
  users = messageSubscribers msg,
    fields: username: true
  _.sortBy (user.username for user in users), userSortKey

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
          to: user.username
          seen: false
      else
        @ready()
  Meteor.publish 'notifications.all', () ->
    @autorun ->
      user = findUser @userId
      if user?
        Notifications.find
          to: user.username
      else
        @ready()

  notifiers = {}

  @notifyMessageUpdate = (diff, created = false) ->
    msg = Messages.findOne diff.id
    subscribers = messageSubscribers msg
    ## Don't send notifications to myself, if so requested.
    subscribers = (to for to in subscribers when not
      (diff.updators.length == 1 and
       diff.updators[0] == to.username and not notifySelf to))
    ## Only notify people who can read the message!  Already checked by
    ## messageSubscribers, and checked again during notification.
    ## Currently superuser can see everything, so they get notified about
    ## everything in the groups they are members of.
    #subscribers = (to for to in subscribers when canSee msg, false, to)
    return unless subscribers.length > 0
    ## Coallesce past notification (if it exists) into this notification,
    ## if they regard the same message and haven't yet been seen by user.
    notifications = Notifications.find
      type: 'messageUpdate'
      to: $in: (to.username for to in subscribers)
      message: diff.id
      seen: false
    .fetch()
    if notifications.length > 0
      Notifications.update
        _id: $in: (notification._id for notification in notifications)
      ,
        $push:
          dates: diff.updated
          diffs: diff._id
      ,
        multi: true
      byUsername = {}
      for notification in notifications
        byUsername[notification.to] = notification
        notification.dates.push diff.updated
        notification.diffs.push diff._id
        notificationSchedule notification
        ## Assuming we don't need to check `created` here, as message existed.
      ## Reduce to the "new" subscribers which had no prior notification.
      subscribers = (to for to in subscribers when to.username not of byUsername)
    if subscribers.length > 0
      notifications =
        for to in subscribers
          notification =
            type: 'messageUpdate'
            to: to.username
            message: diff.id
            dates: [diff.updated]
            diffs: [diff._id]
            seen: false
          if created
            notification.created = created
          notification
      ids = Notifications.insertMany notifications
      for notification, i in notifications
        notification._id = ids[i]
        notificationSchedule notification

  ## No longer used directly; instead use insertMany()
  #notificationInsert = (notification) ->
  #  notification.seen = false
  #  notification._id = Notifications.insert notification
  #  notificationSchedule notification

  ## No longer used directly; instead use updateMany()
  #notificationUpdate = (old, update) ->
  #  Notifications.update old._id, update
  #  notificationSchedule old  ## doesn't include update, but has _id & to fields

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
      "<a href=\"#{url}\">#{group}</a>"
    else
      "#{group} [#{url}]"

  linkToMessage = (msg, html, quote = false) ->
    #url = Meteor.absoluteUrl "#{msg.group}/m/#{msg._id}"
    url = urlFor 'message',
      group: msg.group
      message: msg._id
    if html
      if quote
        """&ldquo;<a href=\"#{url}\">#{formatTitleOrFilename msg, true, true}</a>&rdquo;"""
      else
        #"<a href=\"#{url}\">#{_.escape titleOrUntitled msg}</a>"
        """<a href=\"#{url}\">#{formatTitleOrFilename msg, true, true}</a>"""
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
            delete changed.published if msg.published
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
          if changed.title or changed.published or changed.deleted or changed.private or changed.format or changed.tags or changed.file
            html += "<UL>\n"
            if changed.title
              text += "  * Title changed\n"
              html += "<LI>Title changed\n"
            if changed.published
              if msg.published
                text += "  * PUBLISHED\n"
                html += "<LI>PUBLISHED\n"
              else
                text += "  * UNPUBLISHED\n"
                html += "<LI>UNPUBLISHED\n"
            if changed.deleted
              if msg.deleted
                text += "  * DELETED\n"
                html += "<LI>DELETED\n"
              else
                text += "  * UNDELETED\n"
                html += "<LI>UNDELETED\n"
            if changed.private
              if msg.private
                text += "  * PRIVATE\n"
                html += "<LI>PRIVATE\n"
              else
                text += "  * PUBLIC\n"
                html += "<LI>PUBLIC\n"
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
