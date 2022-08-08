import {Accounts} from 'meteor/accounts-base'
import {Email} from 'meteor/email'

#import {dateMin, dateMax} from '/lib/dates'
import {formatBody, formatTitleOrFilename} from '/lib/formats'
import {angle180, messageContentFields, messageEmpty, messageFilterExtraFields} from '/lib/messages'
import {defaultNotificationDelays, notificationsSeparate, notifySelf, messageSubscribers} from '/lib/notifications'
import {escapeTag, linkToTag, sortTags, tagValueToString} from '/lib/tags'
import {profiling, profilingStartup, isProfiling} from '/lib/profiling'
import {timezoneCanon} from '/lib/settings'

## Only server needs dayjs plugins
import dayjs from 'dayjs'
import utc from 'dayjs/plugin/utc'
import timezone from 'dayjs/plugin/timezone'
import advancedFormat from 'dayjs/plugin/advancedFormat'
dayjs.extend utc
dayjs.extend timezone
dayjs.extend advancedFormat

export serverTimezone =
  ## Server/default timezone: Use settings's coauthor.timezone if specified.
  ## Otherwise, try dayjs's guessing function.
  Meteor.settings?.coauthor?.timezone ? dayjs.tz.guess()

console.log 'Server timezone:', serverTimezone

export dayjsInUserTimezone = (date, user = Meteor.user()) ->
  date = dayjs date unless date instanceof dayjs
  zone = user?.profile?.timezone
  zone = timezoneCanon zone if zone?
  try
    return date.tz zone if zone
  ## Default timezone is the server's timezone
  date.tz serverTimezone

export notificationTime = (base, user) ->
  ## base = notification.dateMin
  user = findUsername user
  delays = user.profile?.notifications?.after ?
           defaultNotificationDelays.after
  try
    dayjs(base).add(delays.after, delays.unit).toDate()
  catch
    ## Handle buggy specification of user.profile.notifications.after
    delays = defaultNotificationDelays.after
    dayjs(base).add(delays.after, delays.unit).toDate()
  ## Old settle dynamics:
  #settleTime = dayjs(dateMax(notification.dates...)).add(delays.settle, delays.unit).toDate()
  #maximumTime = dayjs(dateMin(notification.dates...)).add(delays.maximum, delays.unit).toDate()
  #dateMin settleTime, maximumTime

indentLines = (text, indent) ->
  text.replace /^/gm, indent

## Notification consists of
##   - to: username to notify
##   - group: group relevant to notification (if any)
##   - dateMin: earliest date of update
##   - dateMax: latest date of update (set only when seen becomes true)
##   [- dates: list of dates of all updates]
##   - type: 'messageUpdate'
##     - message: ID of relevant message
##     - old: Copy of message before this batch of updates
##     - oldCanSee: Whether old message was visible to user before updates
##     - new: Copy of message after this batch of updates
##            (set only when seen becomes true)
##     [- diffs: list of IDs of MessagesDiff (in bijection with dates list)]
##   - possible future types: 'import', 'superdelete', 'users', 'settings'
##   - seen: true/false (whether notification has been delivered/deleted)
##   - [level: one of notificationLevels ('batched', 'settled', or 'instant')]

Meteor.publish 'notifications', ->
  @autorun ->
    user = findUser @userId
    if user?
      Notifications.find
        to: user.username
        seen: false
    else
      @ready()
###
Meteor.publish 'notifications.all', ->
  @autorun ->
    user = findUser @userId
    if user?
      Notifications.find
        to: user.username
        seen: $in: [false, true]  # help use index
    else
      @ready()
###

notifiers = {}

@notifyMessageUpdate = (updates, old) ->
  ## Compute current state of message from old + updates, to find subscribers.
  ## Updates might look like "authors.USERNAME": ..., so handle dots.
  if old?
    msg = _.clone old
    for key, value of updates
      where = msg
      whereOld = old
      while (dot = key.indexOf '.') >= 0
        subkey = key[...dot]
        if subkey of where
          if where[subkey] == whereOld?[subkey]
            where[subkey] = _.clone where[subkey]
        else
          where[subkey] = {}
        where = where[subkey]
        whereOld = whereOld?[subkey]
        key = key[dot+1..]
      where[key] = value
  else
    msg = updates
  ## Compute who to notify.
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
  ## Coalesce past notification (if it exists) into this notification,
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
  console.log "find old notifications [#{after.getTime()-before.getTime()} ms]" if isProfiling
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
    old = messageFilterExtraFields old
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
          old: old
          oldCanSee: canSee old, false, to
        notification
    ids = Notifications.insertMany notifications
    after = new Date
    console.log "add new notifications [#{after.getTime()-before.getTime()} ms]" if isProfiling
    before = new Date
    for notification, i in notifications
      notification._id = ids[i]
      notificationSchedule notification, subscribers[i]
    after = new Date
    console.log "scheduling [#{after.getTime()-before.getTime()} ms]" if isProfiling
@notifyMessageUpdate =
  profiling 'notifications.notifyMessageUpdate', @notifyMessageUpdate

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
  Notifications.find
    to: to
    seen: false
  .forEach (notification) ->
    notificationSchedule notification, user

linkToGroup = (group, html) ->
  #url = Meteor.absoluteUrl "#{group}"
  url = urlFor 'group',
    group: group
  if html
    "<a href=\"#{url}\">#{group}</a>"
  else
    "#{group} [#{url}]"

linkToMessage = (msg, user, html, quote = false) ->
  #url = Meteor.absoluteUrl "#{msg.group}/m/#{msg._id}"
  url = urlFor 'message',
    group: msg.group
    message: msg._id
  if html
    options =
      leaveTeX: true  # KaTeX CSS not in email
      me: user.username
    if quote
      """&ldquo;<a href=\"#{url}\">#{formatTitleOrFilename msg, options}</a>&rdquo;"""
    else
      #"<a href=\"#{url}\">#{_.escape titleOrUntitled msg}</a>"
      """<a href=\"#{url}\">#{formatTitleOrFilename msg, options}</a>"""
  else
    if quote
      """"#{titleOrUntitled msg}" [#{url}]"""
    else
      """#{titleOrUntitled msg} [#{url}]"""

linkTag = (text, tag, group) ->
  "<a href=\"#{linkToTag tag, group, true}\">#{text}</a>"

autoHeaders =
  'Auto-Submitted': 'auto-generated'
  Precedence: 'bulk'
  #'X-Auto-Response-Suppress': 'OOF'

notificationEmail = (notifications) ->
  return unless notifications.length > 0
  user = findUsername notifications[0].to
  emails = (email.address for email in user.emails when email.verified)
  ## If no verified email address, don't send, but still mark notification
  ## read.  (Otherwise, upon verifying, you'd get a ton of email.)
  return unless emails.length > 0

  messageUpdates = (notification for notification in notifications when notification.type == 'messageUpdate')
  ## Coalesce multiple updates about the same message, keeping just the
  ## oldest old version.  This can happen because an unfortunate delay
  ## during `messageNotifyUpdate` (between `find` and `insertMany`).
  messageUpdates =
    for msg, cluster of _.groupBy messageUpdates, 'message'
      if cluster.length > 1
        oldest = _.min [0...cluster.length],
          (i) -> cluster[i].dateMin.getTime()
        for notification, i in cluster when i != oldest
          Notifications.remove notification._id
        cluster[oldest]
      else
        cluster[0]
  ## Load new version of updated messages.
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
      ## Detect which fields have changed between old and new
      for key in messageContentFields
        unless _.isEqual notification.new[key], notification.old[key]
          notification.changed[key] = true
      ## Force certain fields to be viewed as changed if this is the first
      ## time this user can see this message.
      unless notification.oldCanSee ? true
        for key in ['body']
          notification.changed[key] = true if key of notification.new
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
    for [, rootUpdates, rootmsg] in bythread
      html += "<H2>#{linkToMessage rootmsg, user, true}</H2>\n\n"
      text += "--- #{linkToMessage rootmsg, user, false} ---\n\n"
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
        ## Colors for adjectives based on .contents styles
        adjectivesText = []
        adjectivesHTML = []
        unless msg.published
          adjectivesText.push 'UNPUBLISHED '
          adjectivesHTML.push '<span style="color:#8a6d3b">UNPUBLISHED</span> '
        if msg.deleted
          adjectivesText.push 'DELETED '
          adjectivesHTML.push '<span style="color:#a94442">DELETED</span> '
        if msg.private
          adjectivesText.push 'PRIVATE '
          adjectivesHTML.push '<span style="color:#5bc0de">PRIVATE</span> '
        if msg.minimized
          adjectivesText.push 'MINIMIZED '
          adjectivesHTML.push '<span style="color:#449d44">MINIMIZED</span> '
        if msg.pinned
          adjectivesText.push 'PINNED '
          adjectivesHTML.push '<span style="color:#a8871f">PINNED</span> '
        if msg.protected
          adjectivesText.push 'PROTECTED '
          adjectivesHTML.push '<span style="color:#5bc0de">PROTECTED</span> '
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
          ## Ignore coauthors on creation if it's still just the creator
          delete changed.coauthors if _.isEqual msg.coauthors, [msg.creator]
          delete changed.access if msg.access?.length == 0
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
        updated = dayjsInUserTimezone msg.updated, user
        dates = "on #{updated.format 'ddd, MMM D, YYYY [at] H:mm z'}"
        if msg.root?
          html += "<P><B>#{authorsHTML}</B> #{verb} #{adjectivesHTML.join ''}message #{linkToMessage msg, user, true, true} in the thread #{linkToMessage rootmsg, true, true} #{dates}:"
          text += "#{authorsText} #{verb} #{adjectivesText.join ''}message #{linkToMessage msg, user, false, true} in the thread #{linkToMessage rootmsg, user, false, true} #{dates}:"
        else
          if verb == 'created'
            noun = 'thread'
          else
            noun = 'root message in the thread'
          html += "<P><B>#{authorsHTML}</B> #{verb} #{adjectivesHTML.join ''}#{noun} #{linkToMessage msg, user, true, true} #{dates}:"
          text += "#{authorsText} #{verb} #{adjectivesText.join ''}#{noun} #{linkToMessage msg, user, false, true} #{dates}:"
        html += '\n\n'
        text += '\n\n'
        ## xxx also could use diff on body
        if changed.body
          if msg.body.trim().length > 0
            bodyHtml = formatBody msg.format, msg.body,
              leaveTeX: true  # KaTeX CSS not in email
              me: user.username
              id: msg._id
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
          if old?.title
            bullet "Title changed from \"#{titleOrUntitled old}\"",
                    "Title changed from &ldquo;#{formatTitleOrFilename old,
                      leaveTeX: true
                      me: user.username}&rdquo;"
          else
            bullet "Title added"
        for key in ['coauthors', 'access']
          continue unless changed[key]
          authors =
            for author in msg[key]
              author: author
              diff: if old? and author not in (old[key] ? []) then '+' else ''
          for author in old?[key] ? []
            if author not in msg[key]
              authors.push
                author: author
                diff: '-'
          bullet "#{capitalize key}: " + (
            for coauthor in authors
              coauthor.diff + displayUser coauthor.author
          ).join(', '), "#{capitalize key}: " + (
            for coauthor in authors
              author = linkToAuthor msg.group, coauthor.author
              switch coauthor.diff
                when '+'
                  "+<ins>#{author}</ins>"
                when '-'
                  "&minus;<del>#{author}</del>"
                else
                  author
          ).join(', ')
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
        if changed.pinned
          if msg.pinned
            bullet "PINNED"
          else
            bullet "UNPINNED"
        if changed.protected
          if msg.protected
            bullet "PROTECTED"
          else
            bullet "UNPROTECTED"
        if changed.format
          bullet "Format: #{msg.format}"
        if changed.tags
          tags =
            for tag in sortTags msg.tags
              escaped = escapeTag tag.key
              tag.oldValue = tagValueToString old?.tags?[escaped]
              tag.diff =
                if tag.oldValue?
                  if tag.value == tag.oldValue
                    ''
                  else
                    '*'
                else
                  '+'
              tag
          for tag in sortTags old?.tags
            if escapeTag(tag.key) not of (msg.tags ? {})
              tag.diff = '-'
              tags.push tag
          for tag in tags
            tag.content = (html) ->
              linker = if html then linkTag else (x) -> x
              linker(tag.key, {key: tag.key}, msg.group) +
              if tag.value
                " = #{linker tag.value, tag, msg.group}"
              else
                ''
          bullet "Tags: " + (
            for tag in tags
              if tag.diff == '*'
                "*#{tag.key} = #{tag.oldValue} -> #{tag.value}"
              else
                tag.diff + tag.content false
          ).join(', '), "Tags: " + (
            for tag in tags
              switch tag.diff
                when '+'
                  "+<ins>#{tag.content true}</ins>"
                when '-'
                  "&minus;<del>#{tag.content true}</del>"
                when '*'
                  "*#{linkTag tag.key, {key: tag.key}, msg.group} = " +
                  "<del>#{linkTag tag.oldValue, {key: tag.key, value: tag.oldValue}, msg.group}</del> " +
                  "&rarr; <ins>#{linkTag tag.value, tag, msg.group}</ins>"
                else
                  tag.content true
          ).join(', ')
        if changed.file
          file = findFile msg.file
          if file?
            bullet """File upload: "#{file.filename}" (#{file.length} bytes)""",
                    "File upload: &ldquo;#{file.filename}&rdquo; (#{file.length} bytes)"
          else
            bullet "File upload: #{msg.file}?"
        if changed.rotate
          delta = angle180 (msg.rotate ? 0) - (old?.rotate ? 0)
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

  ## Expand some CSS classes
  html = html
  .replace /<span class="highlight">/g,
            '<span style="background:yellow;color:black">'

  Email.send
    from: Accounts.emailTemplates.from
    to: emails
    subject: '[Coauthor] ' + subject
    html: html
    text: text
    headers: autoHeaders

profilingStartup 'notifications.startup', ->
  ## Reschedule any leftover notifications from last server run.
  count = 0
  Notifications.find
    seen: false
  .forEach (notification) ->
    count++
    try
      #console.log 'Scheduling leftover notification', notification
      notificationSchedule notification
    catch e
      console.warn 'Could not schedule', notification, ':', e

  ## Watch for change in notification frequency, and reschedule timeouts.
  users = Meteor.users.find {},
    fields:
      'username': true
      'profile.notifications.after': true  ## for @notificationTime
  users.observe
    changed: (user) ->
      notificationReschedule user

  "Scheduled #{count} leftover notifications and loaded #{users.count()} users"
