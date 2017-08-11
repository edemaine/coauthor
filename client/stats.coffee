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

Template.statsGood.onCreated ->
  @stats =
    user:
      query: -> messagesByQuery(@group, @username)
      datasets: [
        label: 'Authored posts',
        borderWidth: 4
        colorFunc: purple
      ,
        label: 'Posts that @-mention user',
        borderWidth: 4
        colorFunc: blue
      ]
    global:
      query: -> group: @group
      datasets: [
        label: 'All posts',
        borderWidth: 4
        colorFunc: purple
      ]
  datasets = _.flatten (stats.datasets for key, stats of @stats), true
  for dataset in datasets
    dataset.borderColor = dataset.colorFunc 0.6
    dataset.backgroundColor = dataset.colorFunc 0.1
  @autorun =>
    t = Template.currentData()
    unit = currentUnit()
    if unit == 'week'
      weekDay = weekStart()
    format =
      switch unit
        when 'hour'
          'HH:mm'
        when 'day', 'week'
          'ddd, MMM DD, YYYY' #'YYYY-MM-DD'
        when 'month'
          'MMM YYYY' #'YYYY-MM'
        when 'year'
          'YYYY'
    for key, stats of @stats
      if key == 'user'
        continue unless t.username?
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
      if unit == 'hour'
        msgs = _.sortBy msgs.fetch(), (msg) -> moment(msg.created).format 'HH:mm'
      msgs.forEach (msg) =>
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
          else
            day = moment(msg.created).startOf unit
        if lastDate?
          if lastDate.valueOf() > day.valueOf()
            console.warn "Backwards time travel from #{lastDate.format()} to #{day.format()}"
            lastDate = day
            makeDay()
          else
            while lastDate.valueOf() != day.valueOf()
              lastDate = lastDate.add 1, unit
              makeDay()
        else
          lastDate = day
          makeDay()
        switch key
          when 'user'
            if escapeUser(t.username) of msg.authors
              stats.datasets[0].data[stats.datasets[0].data.length-1] += 1
            if atMentioned msg, t.username
              stats.datasets[1].data[stats.datasets[1].data.length-1] += 1
          when 'global'
            stats.datasets[0].data[stats.datasets[0].data.length-1] += 1
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
          else
            dataset.pointBorderColor.push dataset.colorFunc 1
      stats.chart?.update 1000

Template.statsGood.onRendered ->
  `import('chart.js')`.then (Chart) =>
    Chart.defaults.global.hover.intersect = false
    Chart.defaults.global.hover.mode = 'index'
    Chart.defaults.global.tooltips.intersect = false
    Chart.defaults.global.tooltips.mode = 'index'

    for key, stats of @stats
      dom = @find "canvas.#{key}Stats"
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
    linkToAuthor @group, @username
  postCount: (type) ->
    Messages.find Template.instance().stats[type].query.call(@)
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
