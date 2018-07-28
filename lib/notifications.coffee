import { profiling, isProfiling } from './profiling.coffee'
import { messageContentFields, messageFilterExtraFields } from './messages.coffee'

@Notifications = new Mongo.Collection 'notifications'

autoHeaders =
  'Auto-Submitted': 'auto-generated'
  Precedence: 'bulk'
  #'X-Auto-Response-Suppress': 'OOF'

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
  ## None of the following actually do anything yet:
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

@notificationsSeparate = (user = Meteor.user()) ->
  user.profile.notifications?.separate

@notifySelf = (user = Meteor.user()) ->
  #user = findUser user if _.isString user
  user.profile.notifications?.self

#@autosubscribeGroup = (group, user = Meteor.user()) ->
#  user.profile?.notifications?.autosubscribe?[escapeGroup group] != false

@autosubscribe = (group, user = Meteor.user()) ->
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
@subscribedToMessage = (message, user = Meteor.user()) ->
  message = findMessage message
  root = message.root ? message._id
  #canSee(message, false, user) and \
  #memberOfGroup(message.group, user) and \
  if autosubscribe message.group, user
    root not in (user.profile.notifications?.unsubscribed ? [])
  else
    root in (user.profile.notifications?.subscribed ? [])

## Mimicks logic of subscribedToMessage above, plus requires group membership,
## verified email, and canSee (everything required for notifications).
## memberOfGroup test prevents users with global permissions from
## autosubscribing to everything.  Also easier to find subscribers
## by starting with group's members.
@messageSubscribers = (msg, options = {}) ->
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
  (user for user in users when subscribedToMessage(msg, user) and canSee msg, false, user, group)
@messageSubscribers =
  profiling @messageSubscribers, 'notifications.messageSubscribers'

@sortedMessageSubscribers = (msg, options = {}) ->
  if options.fields?
    options.fields.username = true
    options.fields['profile.fullname'] = true  ## for sorting by fullname
  users = messageSubscribers msg, options
  _.sortBy users, userSortKey

@notificationTime = (base, user) ->
  ## base = notification.dateMin
  user = findUsername user
  delays = user.profile?.notifications?.after ?
           defaultNotificationDelays.after
  try
    moment(base).add(delays.after, delays.unit).toDate()
  catch e
    ## Handle buggy specification of user.profile.notifications.after
    delays = defaultNotificationDelays.after
    moment(base).add(delays.after, delays.unit).toDate()
  ## Old settle dynamics:
  #settleTime = moment(dateMax(notification.dates...)).add(delays.settle, delays.unit).toDate()
  #maximumTime = moment(dateMin(notification.dates...)).add(delays.maximum, delays.unit).toDate()
  #dateMin settleTime, maximumTime

## Notification consists of
##   - to: username to notify
##   - group: group relevant to notification (if any)
##   - dateMin: earliest date of update
##   - dateMax: latest date of update (set only when seen becomes true)
##   [- dates: list of dates of all updates]
##   - type: 'messageUpdate'
##     - message: ID of relevant message
##     - old: Copy of message before this batch of updates
##     - new: Copy of message after this batch of updates
##            (set only when seen becomes true)
##     [- diffs: list of IDs of MessagesDiff (in bijection with dates list)]
##   - possible future types: 'import', 'superdelete', 'users', 'settings'
##   - seen: true/false (whether notification has been delivered/deleted)
##   - [level: one of notificationLevels ('batched', 'settled', or 'instant')]

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

  @notifyMessageUpdate = (updates, old) ->
    ## Compute current state of message from old + msg, to find subscribers.
    ## Updates in msg might look like "authors.USERNAME": ..., so handle dots.
    if old?
      msg = _.clone old
      for key, value of updates
        where = msg
        while (dot = key.indexOf '.') >= 0
          subkey = key[...dot]
          where[subkey] = {} unless subkey of where
          where = msg[subkey]
          key = key[dot+1..]
        where[key] = value
    else
      msg = updates
    subscribers = messageSubscribers msg
    ## Don't send notifications to myself, if so requested.
    subscribers = (to for to in subscribers when not
      (msg.updators.length == 1 and
       msg.updators[0] == to.username and not notifySelf to))
    ## Only notify people who can read the message!  Already checked by
    ## messageSubscribers, and checked again during notification.
    ## Currently superuser can see everything, so they get notified about
    ## everything in the groups they are members of.
    #subscribers = (to for to in subscribers when canSee msg, false, to)
    ## Check if filters have completely emptied subscriber list.
    return unless subscribers.length > 0
    ## Coallesce past notification (if it exists) into this notification,
    ## if they regard the same message and haven't yet been seen by user.
    before = new Date
    notifications = Notifications.find
      type: 'messageUpdate'
      to: $in: (to.username for to in subscribers)
      message: msg._id
      seen: false
    ,
      fields: to: true
    .fetch()
    after = new Date
    console.log 'find old notifications', after.getTime()-before.getTime() if isProfiling
    if notifications.length > 0
      ## No longer store entire list of dates and diffs, so don't need to
      ## update old notifications.
      #Notifications.update
      #  _id: $in: (notification._id for notification in notifications)
      #,
      #  $push:
      #    dates: diff.updated
      #    diffs: diff._id
      #,
      #  multi: true
      byUsername = {}
      for notification in notifications
        byUsername[notification.to] = notification
        ## Given that we're updating past notifications, they should already
        ## be scheduled with an earlier date.  So no need to reschedule.
        #notification.dates.push diff.updated
        #notification.diffs.push diff._id
        #notificationSchedule notification
        ## Assuming we don't need to check `created` here, as message existed.
      ## Reduce to the "new" subscribers which had no prior notification.
      subscribers = (to for to in subscribers when to.username not of byUsername)
    if subscribers.length > 0
      before = new Date
      notifications =
        for to in subscribers
          notification =
            type: 'messageUpdate'
            to: to.username
            group: msg.group
            message: msg._id
            dateMin: msg.updated
            #diffs: [diff._id]
            seen: false
            old: messageFilterExtraFields old
          notification
      ids = Notifications.insertMany notifications
      after = new Date
      console.log 'add new notifications', after.getTime()-before.getTime() if isProfiling
      before = new Date
      for notification, i in notifications
        notification._id = ids[i]
        notificationSchedule notification, subscribers[i]
      after = new Date
      console.log 'scheduling', after.getTime()-before.getTime() if isProfiling
  @notifyMessageUpdate =
    profiling @notifyMessageUpdate, 'notifications.notifyMessageUpdate'

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

  notificationSchedule = (notification, user = notification.to) ->
    base = notification.dateMin
    username = user.username ? user
    ## If a batch notification is already scheduled earlier than this one
    ## would be, then that will cover this notification, so we don't need to
    ## schedule anything new.  But if this notification is more urgent (this
    ## will happen when server starts with expired messages, for example),
    ## we should reschedule.  Finally, if a notification is already running,
    ## we also don't need to do anything, because at the end of running the
    ## notifier will check for any new notifications to schedule.
    if username of notifiers
      return if notifiers[username].running
      return if notifiers[username].base.getTime() <= base.getTime()
    else
      notifiers[username] = {}
    notifiers[username].base = base
    notifiers[username].group = notification.group
    notificationReschedule user

  notificationReschedule = (user) ->
    ## Call this once notifiers[username].base has been set,
    ## and either the timeout hasn't been scheduled yet (notificationSchedule)
    ## or the user's notification parameters have changed so the timeout
    ## might need to be rescheduled.
    username = user.username ? user
    return unless username of notifiers
    return if notifiers[username].running
    time = notificationTime notifiers[username].base, user
    return if time.getTime() == notifiers[username].time?.getTime()
    if notifiers[username].timeout?
      Meteor.clearTimeout notifiers[username].timeout
    notifiers[username].time = time
    now = new Date()
    #console.log username, '@', time.getTime() - now.getTime()
    notifiers[username].timeout =
      Meteor.setTimeout ->
        notificationDo username
      , Math.max(minSchedule, time.getTime() - now.getTime())

  notificationDo = (to) ->
    ## During this callback, prevent other notifications from scheduling.
    notifiers[to].running = true
    Meteor.clearTimeout notifiers[to].timeout
    query =
      to: to
      seen: false
    user = findUsername to
    if notificationsSeparate user
      query.group = notifiers[to].group
    notifications = Notifications.find query
    .fetch()
    notificationEmail notifications
    for notification in notifications
      Notifications.update notification._id,
        $set:
          seen: true
          new: notification.new
    ## Now we relinquish the 'lock' set by notifiers[to].
    delete notifiers[to]
    ## In the meantime, new notifications may have appeared; schedule them.
    ## Or, if we just notified about one group, other groups' notifications
    ## might remain.
    notifications = Notifications.find
      to: to
      seen: false
    .fetch()
    if notifications.length > 0
      for notification in notifications
        notificationSchedule notification, user

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
      #url = urlFor 'tag',
      #  group: group
      #  tag: tag
      url = urlFor 'search',
        group: group
        search: "tag:#{tag}"
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
      notification.new =
        messageFilterExtraFields Messages.findOne notification.message
    ## Some messages may have been superdeleted by now; don't email about them.
    messageUpdates = (notification for notification in messageUpdates when notification.new?)
    ## Ignore messages that have been hidden from this user since (e.g. deleted)
    messageUpdates = (notification for notification in messageUpdates when canSee notification.new, false, user)
    ## Don't notify about empty messages (e.g. initial creation without
    ## follow-up) -- wait for content.  xxx should check if diff is version 1!
    messageUpdates = (notification for notification in messageUpdates when not messageEmpty notification.new)
    ## Compute notifications authors and changed tables.
    for notification in messageUpdates
      notification.changed = {}
      notification.authors = _.keys(notification.new.authors ? {})
      if notification.old?
        ## Filter authors to those who modified since old update time.
        oldUpdated = notification.old.updated.getTime()
        notification.authors = (author for author in notification.authors \
          when notification.new.authors[author].getTime() > oldUpdated)
        for key in messageContentFields
          unless _.isEqual notification.new[key], notification.old[key]
            notification.changed[key] = true
      else
        for key in messageContentFields
          notification.changed[key] = true if key of notification.new
      notification.authors = (unescapeUser author for author in notification.authors)
    ## Ignore messages that ended up not changing since the old version
    ## (e.g., changed then unchanged).
    messageUpdates = (notification for notification in messageUpdates when 0 < _.size notification.changed)

    return if messageUpdates.length == 0

    html = ''
    text = ''
    bygroup = _.groupBy messageUpdates, (notification) -> notification.new.group
    subject = "#{messageUpdates.length} updates in #{_.keys(bygroup).sort().join ', '}"
    bygroup = _.pairs bygroup
    bygroup = _.sortBy bygroup, (pair) -> pair[0]
    for [group, groupUpdates] in bygroup
      bythread = _.groupBy groupUpdates,
        (notification) -> notification.new.root ? notification.new._id
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
          if notification.new.root?
            notification.dateMin.getTime()
          else
            0  ## put root at top
        for notification in rootUpdates
          msg = notification.new
          old = notification.old
          if old?
            verb = 'updated'
          else
            verb = 'created'
          adjectives = ''
          unless msg.published
            adjectives += 'unpublished '
          if msg.deleted
            adjectives += 'deleted '
          if msg.private
            adjectives += 'private '
          if msg.minimized
            adjectives += 'minimized '
          changed = notification.changed
          unless old?
            ## Ignore some initial values during creation of message.
            delete changed.published if msg.published
            delete changed.deleted unless msg.deleted
            delete changed.tags unless 0 < _.size msg.tags
            ## Don't notify about title or format change when brand new
            delete changed.title
            delete changed.format
            ## Don't notify about empty body on new file message
            delete changed.body if msg.file and not msg.body
          authors = _.sortBy notification.authors, userSortKey
          authorsText = (displayUser author for author in authors).join ', '
          authorsHTML = (linkToAuthor msg.group, author for author in authors).join ', '
          if messageUpdates.length == 1
            subject = "#{authorsText} #{verb} '#{titleOrUntitled msg}' in #{msg.group}"
          else
            if pastAuthors?
              unless pastAuthors == authorsText
                pastAuthors = false
            else
              pastAuthors = authorsText
              authorsSubject = "#{authorsText} made #{subject}" ## n updates in ...
          #if diffs.length > 1
          #  dates = "between #{diffs[0].updated} and #{diffs[diffs.length-1].updated}"
          #else
          updated = momentInUserTimezone msg.updated, user
          dates = "on #{updated.format 'ddd, MMM D, YYYY [at] H:mm z'}"
          if msg.root?
            html += "<P><B>#{authorsHTML}</B> #{verb} #{adjectives}message #{linkToMessage msg, true, true} in the thread #{linkToMessage rootmsg, true, true} #{dates}:"
            text += "#{authorsText} #{verb} #{adjectives}message #{linkToMessage msg, false, true} in the thread #{linkToMessage rootmsg, false, true} #{dates}:"
          else
            html += "<P><B>#{authorsHTML}</B> #{verb} #{adjectives}root message in the thread #{linkToMessage msg, true, true} #{dates}:"
            text += "#{authorsText} #{verb} #{adjectives}root message in the thread #{linkToMessage msg, false, true} #{dates}:"
          html += '\n\n'
          text += '\n\n'
          ## xxx also could use diff on body
          if changed.body
            if msg.body.trim().length > 0
              bodyHtml = formatBody msg.format, msg.body, true
              bodyText = msg.body
            else
              bodyHtml = bodyText = '(empty body)'
            html += "<BLOCKQUOTE>\n#{bodyHtml}\n</BLOCKQUOTE>\n"
            text += indentLines(bodyText, '    ') + "\n"
            text += '\n' unless msg.body and msg.body[msg.body.length-1] == '\n'
          textBullets = []
          htmlBullets = []
          bullet = (textBullet, htmlBullet = textBullet) ->
            textBullets.push "  * #{textBullet}\n"
            htmlBullets.push "<LI>#{htmlBullet}\n"
          if changed.title
            if old.title
              bullet "Title changed from \"#{titleOrUntitled old}\"",
                     "Title changed from &ldquo;#{formatTitleOrFilename old, true, true}&rdquo;"
            else
              bullet "Title added"
          if changed.published
            if msg.published
              bullet "PUBLISHED"
            else
              bullet "UNPUBLISHED"
          if changed.deleted
            if msg.deleted
              bullet "DELETED"
            else
              bullet "UNDELETED"
          if changed.private
            if msg.private
              bullet "PRIVATE"
            else
              bullet "PUBLIC"
          if changed.minimized
            if msg.minimized
              bullet "MINIMIZED"
            else
              bullet "UNMINIMIZED"
          if changed.format
            bullet "Format: #{msg.format}"
          if changed.tags
            ## xxx diff tags
            bullet "Tags: #{linkToTags msg.group, msg.tags, false}",
                   "Tags: #{linkToTags msg.group, msg.tags, true}"
          if changed.file
            file = findFile msg.file
            if file?
              bullet """File upload: "#{file.filename}" (#{file.length} bytes)""",
                     "File upload: &ldquo;#{file.filename}&rdquo; (#{file.length} bytes)"
            else
              bullet "File upload: #{msg.file}?"
          if changed.rotate
            delta = angle180 (msg.rotate ? 0) - (old.rotate ? 0)
            if delta != 0
              if delta != (msg.rotate ? 0)
                bullet "Rotated #{delta}° (now #{msg.rotate ? 0}°)"
              else
                bullet "Rotated #{delta}°"
          if textBullets.length > 0
            text += textBullets.join ''
          if htmlBullets.length > 0
            html += "<UL>\n"
            html += htmlBullets.join ''
            html += "</UL>\n"
          html += '\n'
          text += '\n'
    if pastAuthors
      subject = authorsSubject

    Email.send
      from: Accounts.emailTemplates.from
      to: emails
      subject: '[Coauthor] ' + subject
      html: html
      text: text
      headers: autoHeaders

  Meteor.startup ->
    ## Reschedule any leftover notifications from last server run.
    Notifications.find
      seen: false
    .forEach (notification) ->
      try
        #console.log 'Scheduling leftover notification', notification
        notificationSchedule notification
      catch e
        console.warn 'Could not schedule', notification, ':', e

    ## Watch for change in notification frequency, and reschedule timeouts.
    Meteor.users.find {},
      fields:
        'username': true
        'profile.notifications.after': true  ## for @notificationTime
    .observe
      changed: (user) ->
        notificationReschedule user
