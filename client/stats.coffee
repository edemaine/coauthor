defaultUnit = 'week'
currentUnit = ->
  Template.currentData().unit or defaultUnit

defaultWeekStart = 0  ## Sunday
weekStart = ->
  groupData()?.weekStart ? defaultWeekStart

purple = (alpha) -> "rgba(102,51,153,#{alpha})"
blue = (alpha) -> "rgba(5,141,199,#{alpha})"

Template.stats.onCreated ->
  if Template.currentData()?.username
    setTitle "Statistics for #{Template.currentData().username}"
  else
    setTitle "Statistics"

unitFormat = (unit) ->
  switch unit
    when 'hour'
      'HH:mm'
    when 'weekday'
      'ddd'
    when 'day', 'week'
      'ddd, MMM DD, YYYY' #'YYYY-MM-DD'
    when 'month'
      'MMM YYYY' #'YYYY-MM'
    when 'year'
      'YYYY'

buildStats = (stats, t) ->
  unit = currentUnit()
  if unit == 'week'
    weekDay = weekStart()
  format = unitFormat unit
  stats.labels = []
  for dataset in stats.datasets
    dataset.data = []
  lastDate = null
  makeDay = =>
    stats.labels.push lastDate.format format
    for dataset in stats.datasets
      dataset.data.push 0
  msgs = Messages.find stats.query.call(t)
  ,
    fields:
      created: true
      body: true
      title: true
      authors: true
    sort: created: 1
  switch unit
    when 'hour'
      msgs = _.sortBy msgs.fetch(), (msg) -> moment(msg.created).format 'HH:mm'
    when 'weekday'
      msgs = _.sortBy msgs.fetch(), (msg) -> moment(msg.created).day()
  msgs.forEach (msg) =>
    increment = unit
    switch unit
      when 'week'
        day = moment(msg.created).startOf 'day'
        if day.day() < weekDay
          day.day -7 + weekDay  ## previous week
        else
          day.day weekDay  ## same week
      when 'hour'
        day = moment(msg.created).startOf unit
        .year 2000
        .dayOfYear 1
      when 'weekday'
        day = moment(msg.created).startOf 'day'
        day = day.date 1 + moment(msg.created).day()
        .month 9
        .year 2000  ## 1st day of October 2000 is a Sunday
        increment = 'day'
      else
        day = moment(msg.created).startOf unit
    if lastDate?
      if lastDate.valueOf() > day.valueOf()
        console.warn "Backwards time travel from #{lastDate.format()} to #{day.format()}"
        lastDate = day
        makeDay()
      else
        while lastDate.valueOf() != day.valueOf()
          lastDate = lastDate.add 1, increment
          makeDay()
          if lastDate.valueOf() > day.valueOf()
            console.warn "Bad day handling (Coauthor bug)"
            break
    else
      lastDate = day
      makeDay()
    for dataset in stats.datasets
      if dataset.msgFilter?
        continue unless dataset.msgFilter.call t, msg
      dataset.data[dataset.data.length-1] += 1
  for dataset in stats.datasets
    dataset.pointBorderColor = []
  for i in [0...stats.labels.length]
    zero = true
    for dataset in stats.datasets
      unless dataset.data[i] == 0
        zero = false
        break
    for dataset in stats.datasets
      if zero
        dataset.pointBorderColor.push 'red'
      else if dataset.colorFunc?
        dataset.pointBorderColor.push dataset.colorFunc 1
      else
        dataset.pointBorderColor.push 'purple'
  stats

Template.statsGood.onCreated ->
  @stats = [
    type: 'user'
    query: -> messagesByQuery(@group, @username)
    datasets: [
      msgFilter: (msg) -> escapeUser(@username) of msg.authors
      label: 'Authored posts'
      borderWidth: 4
      colorFunc: purple
    ,
      msgFilter: (msg) -> atMentioned msg, @username
      label: 'Posts that @-mention user'
      borderWidth: 4
      colorFunc: blue
    ]
  ,
    type: 'global'
    query: -> group: @group
    datasets: [
      label: 'All posts',
      borderWidth: 4
      colorFunc: purple
    ]
  ]
  datasets = _.flatten (stats.datasets for stats in @stats), true
  for dataset in datasets
    dataset.borderColor = dataset.colorFunc 0.6
    dataset.backgroundColor = dataset.colorFunc 0.1
  @autorun =>
    t = Template.currentData()
    for stats in @stats
      if stats.type == 'user'
        continue unless t.username?
      buildStats stats, t
      stats.chart?.update 1000

Template.statsGood.onRendered ->
  tooltipInit()
  `import('chart.js')`.then (Chart) =>
    Chart.defaults.global.hover.intersect = false
    Chart.defaults.global.hover.mode = 'index'
    Chart.defaults.global.tooltips.intersect = false
    Chart.defaults.global.tooltips.mode = 'index'

    for stats in @stats
      dom = @find "canvas.#{stats.type}Stats"
      stats.chart = new Chart.Chart dom,
        type: 'line'
        data: stats
        options:
          scales:
            yAxes: [
              ticks:
                beginAtZero: true
                ## Integer workaround from https://github.com/chartjs/Chart.js/issues/2539
                callback: (tick) ->
                  if 0 <= tick.toString().indexOf '.'
                    null
                  else
                    tick.toLocaleString()
            ]

Template.statsGood.helpers
  hideIfNoUser: ->
    if @username
      ''
    else
      'hidden'
  activeUnit: (which) ->
    if which == currentUnit()
      'active'
    else
      ''
  week: ->
    currentUnit() == 'week'
  unit: ->
    capitalize currentUnit()
  weekStart: ->
    moment().day(weekStart()).format 'dddd'
  activeWeekStart: (which) ->
    if which == weekStart()
      'active'
    else
      ''
  linkToAuthor: ->
    tooltipUpdate()
    if @group? and @username?
      linkToAuthor @group, @username
  postCount: (type) ->
    stats = (s for s in Template.instance().stats when s.type == type)[0]
    Messages.find stats.query.call(@)
    .count()

Template.statsGood.events
  'click .unit': (e) ->
    e.preventDefault()
    e.stopPropagation()
    dropdownToggle e
    Router.go Router.current().route.getName(), Router.current().params,
      query:
        unit: e.target.getAttribute 'data-unit'
  'click .weekStart': (e) ->
    e.preventDefault()
    e.stopPropagation()
    dropdownToggle e
    Meteor.call 'groupWeekStart', @group, parseInt e.target.getAttribute 'data-day'
  'click .downloadTSV a': (e, t) ->
    e.preventDefault()
    e.stopPropagation()
    dropdownToggle e
    msgFilter =
      switch e.target.className
        when 'tsvBoth'
          (username) -> (msg) -> escapeUser(username) of msg.authors or
                                 atMentioned msg, username
        when 'tsvAuthor'
          (username) -> (msg) -> escapeUser(username) of msg.authors
        when 'tsvAts'
          (username) -> (msg) -> atMentioned msg, username
    stats =
      type: 'users'
      query: -> group: @group
      datasets: [
        fullname: 'ALL MESSAGES'
        msgFilter: (msg) -> true
      ].concat Meteor.users.find({}, sort: username: 1).map (user) =>
        username: user.username
        fullname: user.profile?.fullname
        member: if fullMemberOfGroup @group, user then 'full' else 'partial'
        email: user.emails?[0]?.address
        msgFilter: msgFilter user.username
    buildStats stats, t.data
    rows = [['Username', 'Fullname', 'Email', 'Membership', 'Total'].concat stats.labels]
    for dataset in stats.datasets
      rows.push [
        dataset.username ? ''
        dataset.fullname ? ''
        dataset.email ? ''
        dataset.member ? ''
        dataset.data.reduce ((x, y) -> x+y), 0
      ].concat dataset.data
    tsv =
      (for row in rows
        (for cell in row
          escapeTSV cell
        ).join '\t'
      ).join('\n') + '\n'
    blob = new Blob [tsv], type: 'text/plain;charset=utf-8'
    filename = "#{t.data.group}-#{e.target.className[3..].toLowerCase()}.tsv"
    (await import('file-saver')).saveAs blob, filename

## https://en.wikipedia.org/wiki/Tab-separated_values
escapeTSVmap =
  '\\': '\\\\'
  '\n': '\\n'
  '\t': '\\t'
  '\r': '\\r'
escapeTSVre = new RegExp "[#{(key for key of escapeTSVmap).join ''}]", 'g'
escapeTSV = (x) ->
  x.toString().replace escapeTSVre, (match) -> escapeTSVmap[match]
