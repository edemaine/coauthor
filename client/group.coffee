@routeGroupRoute = ->
  Router.current()?.params?.group

@routeGroup = ->
  group = routeGroupRoute()
  if group == wildGroupRoute
    wildGroup
  else
    group

@routeGroupOrWild = ->
  routeGroup() ? wildGroup

Template.registerHelper 'routeGroup', routeGroup

Template.registerHelper 'routeGroupOrWildData', ->
  group: routeGroupOrWild()
  0: '*'

Template.registerHelper 'wildGroup', ->
  routeGroup() == wildGroup

@groupData = ->
  Groups.findOne
    name: routeGroup()

Template.registerHelper 'groupData', groupData

Template.registerHelper 'groupDataOrWild', ->
  routeGroup() == wildGroup or groupData()

@sortBy = ->
  if Router.current().params.sortBy in sortKeys
    key: Router.current().params.sortBy
    reverse: Router.current().route.getName()[-7..] == 'reverse'
  else
    groupDefaultSort routeGroup()

@linkToSort = (sort) ->
  if sort.reverse
    route = 'group.sorted.reverse'
  else
    route = 'group.sorted.forward'
  pathFor route,
    group: routeGroup()
    sortBy: sort.key

Template.registerHelper 'groups', ->
  Groups.find {},
    sort: [['name', 'asc']]

Template.registerHelper 'admin', -> canAdmin routeGroup(), routeMessage()

Template.registerHelper 'canImport', -> canImport @group ? routeGroup()

Template.registerHelper 'canSuper', -> canSuper @group ? routeGroup()

Template.registerHelper 'canSee', -> canSee @

Template.group.onCreated ->
  @autorun ->
    setTitle()

formatMembers = (sortedMembers) ->
  members =
    for member in sortedMembers
      partial = member.rolesPartial?[escapeGroup @group]
      if partial?
        msgs = Messages.find _id: $in: (id for id of partial)
        .fetch()
        title = "User '#{member.username}' has access to " + (
          for msg in msgs
            "“#{titleOrUntitled msg}”"
        ).join '; '
      else
        title = null
      linkToAuthor @group, member, title
  if members.length > 0
    members.join(', ')
  else
    '(none)'

Template.group.helpers
  topMessageCount: ->
    pluralize(groupSortedBy(@group, null).count(), 'message thread')
  groupTags: ->
    groupTags @group
  fullMembersCount: ->
    groupFullMembers(@group).count()
  partialMembersCount: ->
    groupPartialMembers(@group).count()
  fullMembers: ->
    tooltipUpdate()
    formatMembers.call @, sortedGroupFullMembers @group
  partialMembers: ->
    tooltipUpdate()
    formatMembers.call @, sortedGroupPartialMembers @group

Template.groupButtons.helpers
  sortBy: ->
    capitalize sortBy().key
  sortReverse: ->
    sortBy().reverse
  activeSort: ->
    if sortBy().key == @key
      'active'
    else
      ''
  capitalizedKey: ->
    capitalize @key
  sortKeys: ->
    key: key for key in sortKeys
  linkToSort: ->
    linkToSort
      key: @key
      reverse: sortBy().reverse
  linkToReverse: ->
    linkToSort
      key: sortBy().key
      reverse: not sortBy().reverse

  disableMyPosts: ->
    if Meteor.userId()?
      ''
    else
      'disabled'
  linkToMyPosts: ->
    return null unless Meteor.userId()?
    pathFor 'author',
      group: routeGroup()
      author: Meteor.user().username
  linkToStats: ->
    if Meteor.userId()?
      pathFor 'stats',
        group: routeGroup()
        username: Meteor.user().username
    else
      pathFor 'stats.userless',
        group: routeGroup()

  disableClass: ->
    if canPost @group
      ''
    else
      'disabled'
  disableTitle: ->
    if canPost @group
      ''
    else if Meteor.userId()?
      'You do not have permission to post a message in this group.'
    else
      'You need to be logged in to post a message.'

Template.groupButtons.onRendered ->
  tooltipInit()

Template.groupButtons.events
  'click .sortSetDefault': (e) ->
    e.stopPropagation()
    console.log "Setting default sort for #{routeGroup()} to #{if sortBy().reverse then '-' else '+'}#{sortBy().key}"
    Meteor.call 'groupDefaultSort', routeGroup(), sortBy()

  'click .groupRenameButton': (e) ->
    Modal.show 'groupRename'

  'click .postButton': (e) ->
    e.preventDefault()
    e.stopPropagation()
    type = e.target.id
    #$("#poseButton").addClass 'disabled'
    if canPost @group
      group = @group  ## for closure
      Meteor.call 'messageNew', group, (error, result) ->
        #$("#poseButton").removeClass 'disabled'
        if error
          console.error error
        else if result
          Meteor.call 'messageEditStart', result
          Router.go 'message', {group: group, message: result}
        else
          console.error "messageNew did not return problem -- not authorized?"

Template.groupRename.events
  'click .groupRenameButton': (e, t) ->
    e.preventDefault()
    e.stopPropagation()
    groupOld = routeGroup()
    groupNew = t.find('#groupInput').value
    Modal.hide()
    return unless validGroup groupNew  ## ignore blank or otherwise invalid name
    Meteor.call 'groupRename', groupOld, groupNew, (error, result) ->
      if error
        console.error 'groupRename:', error
      else
        Router.go 'group',
          group: groupNew
  'click .cancelButton': (e) ->
    e.preventDefault()
    e.stopPropagation()
    Modal.hide()

Template.importButtons.events
  'click .importButton': (e, t) ->
    e.preventDefault()
    e.stopPropagation()
    t.find(".importInput[data-format='#{e.target.getAttribute('data-format')}']").click()
  'change .importInput': (e, t) ->
    importFiles e.target.getAttribute('data-format'), t.data.group, e.target.files
    e.target.value = ''
  'dragenter .importButton': (e) ->
    e.preventDefault()
    e.stopPropagation()
  'dragover .importButton': (e) ->
    e.preventDefault()
    e.stopPropagation()
  'drop .importButton': (e, t) ->
    e.preventDefault()
    e.stopPropagation()
    importFiles e.target.getAttribute('data-format'), t.data.group, e.originalEvent.dataTransfer.files

  'click .superdeleteImportButton': (e, t) ->
    e.preventDefault()
    e.stopPropagation()
    Modal.show 'superdeleteImport', @

Template.superdeleteImport.events
  'click .superdeleteImportConfirm': (e, t) ->
    e.preventDefault()
    e.stopPropagation()
    Modal.hide()
    console.log 'Loading all messages in group...'
    sub = Meteor.subscribe 'messages.imported', t.data.group, ->
      count = 0
      Messages.find
        group: t.data.group
        imported: $ne: null
      .forEach (msg) ->
        count += 1
        console.log 'Superdeleting', msg._id #, msg.title?[...20]
        Meteor.call 'messageSuperdelete', msg._id
      console.log 'Superdeleted', count, 'imported messages'
      sub.stop()
  'click .cancelButton': (e) ->
    e.preventDefault()
    e.stopPropagation()
    Modal.hide()

Template.messageList.onRendered ->
  mathjax()
  tooltipInit()

Template.messageList.helpers
  linkToSort: (key) ->
    if key == sortBy().key
      linkToSort
        key: key
        reverse: not sortBy().reverse
    else
      linkToSort
        key: key
        ## Default reverse setting when switching sort keys:
        reverse: key in ['published', 'updated', 'posts', 'emoji', 'subscribe']
  sortingBy: (key) ->
    sortBy().key == key
  sortingGlyph: ->
    sort = sortBy()
    if sort.key in ['title', 'creator']
      type = 'alpha'
    else
      type = 'numeric'
    if sort.reverse
      order = 'up'
    else
      order = 'down'
    "fa-sort-#{type}-#{order}"
  topMessages: ->
    groupSortedBy @group, sortBy()

Template.messageShort.onRendered ->
  mathjax()

Template.messageShort.helpers
  messageLink: ->
    pathFor 'message',
      group: @group
      message: @_id
  zeroClass: ->
    if 0 == @submessageCount
      'badge-zero'
    else
      ''
  submessageLastUpdate: ->
    formatDate @submessageLastUpdate
  subscribed: ->
    subscribedToMessage @
  emojiPositive: ->
    emojiReplies @, class: 'positive'
  #emojiNegative: ->
  #  emojiReplies @, class: 'negative'
  emojiCount: ->
    sum = 0
    for emoji in @
      sum += emoji.who.length
    sum
  emojiWho: ->
    tooltipUpdate()
    text = []
    for emoji in @
      for user in emoji.who
        text.push """<span class="fas fa-#{emoji.symbol}"></span> #{displayUser user}"""
    text.join ', '

Template.messageShort.events
  'click button.subscribe': (e, t) ->
    e.preventDefault()
    e.stopPropagation()
    if subscribedToMessage @
      Meteor.users.update Meteor.userId(),
        $push: 'profile.notifications.unsubscribed': @_id
        $pull: 'profile.notifications.subscribed': @_id
    else
      Meteor.users.update Meteor.userId(),
        $push: 'profile.notifications.subscribed': @_id
        $pull: 'profile.notifications.unsubscribed': @_id
