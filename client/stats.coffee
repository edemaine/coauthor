import Chart from 'chart.js'

Chart.defaults.global.hover.intersect = false
Chart.defaults.global.hover.mode = 'index'
Chart.defaults.global.tooltips.intersect = false
Chart.defaults.global.tooltips.mode = 'index'

defaultUnit = 'week'
currentUnit = ->
  Template.currentData().unit or defaultUnit

purple = (alpha) -> "rgba(102,51,153,#{alpha})"
blue = (alpha) -> "rgba(5,141,199,#{alpha})"

Template.statsGood.onCreated ->
  @stats =
    datasets: [
      label: 'Authored posts',
      borderWidth: 4
      colorFunc: purple
    ,
      label: 'Posts that @mention you',
      borderWidth: 4
      colorFunc: blue
    ]
  for dataset in @stats.datasets
    dataset.borderColor = dataset.colorFunc 0.6
    dataset.backgroundColor = dataset.colorFunc 0.1
  @autorun =>
    unit = currentUnit()
    format =
      switch unit
        when 'day', 'week'
          'ddd, MMM DD, YYYY' #'YYYY-MM-DD'
        when 'month'
          'MMM YYYY' #'YYYY-MM'
        when 'year'
          'YYYY'
    username = Meteor.user().username
    @stats.labels = []
    for dataset in @stats.datasets
      dataset.data = []
    lastDate = null
    makeDay = =>
      @stats.labels.push lastDate.format format
      for dataset in @stats.datasets
        dataset.data.push 0
    Messages.find messagesByQuery(Template.currentData().group, username)
    ,
      fields:
        created: true
        body: true
        title: true
        authors: true
      sort: created: 1
    .forEach (msg) =>
      day = moment(msg.created).startOf unit
      if lastDate?
        while lastDate.valueOf() != day.valueOf()
          lastDate = lastDate.add 1, unit
          makeDay()
      else
        lastDate = day
        makeDay()
      if username of msg.authors
        @stats.datasets[0].data[@stats.datasets[0].data.length-1] += 1
      if atMentioned msg, username
        @stats.datasets[1].data[@stats.datasets[1].data.length-1] += 1
    for dataset in @stats.datasets
      dataset.pointBorderColor = []
    for i in [0...@stats.labels.length]
      zero = true
      for dataset in @stats.datasets
        unless dataset.data[i] == 0
          zero = false
          break
      for dataset in @stats.datasets
        if zero
          dataset.pointBorderColor.push 'red'
        else
          dataset.pointBorderColor.push dataset.colorFunc 1
    @chart?.update 1000

Template.statsGood.onRendered ->
  @chart = new Chart @find('.yourStats'),
    type: 'line'
    data: @stats
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
  activeUnit: (which) ->
    if which == currentUnit()
      'active'
    else
      ''
  unit: ->
    capitalize currentUnit()

Template.statsGood.events
  'click .unit': (e) ->
    e.preventDefault()
    e.stopPropagation()
    dropdownToggle e
    Router.go 'stats',
      group: @group
      unit: e.target.getAttribute 'data-unit'
