import Chart from 'chart.js'

Template.statsGood.onCreated ->
  @weekLabels = []
  @postCounts = []
  @autorun =>
    @weekLabels.splice 0, @weekLabels.length
    @postCounts.splice 0, @postCounts.length
    lastDay = null
    makeDay = =>
      @weekLabels.push lastDay.format 'YYYY-MM-DD'
      @postCounts.push 0
    Messages.find messagesByQuery(Template.currentData().group, Meteor.user().username)
    , sort: created: 1
    .forEach (msg) =>
      day = moment(msg.created).startOf 'day'
      if lastDay?
        while lastDay.valueOf() != day.valueOf()
          lastDay = lastDay.add 1, 'days'
          makeDay()
      else
        lastDay = day
        makeDay()
      @postCounts[@postCounts.length-1] += 1
    @chart?.update 1000

Template.statsGood.onRendered ->
  @chart = new Chart @find('.yourStats'),
    type: 'line'
    data:
      labels: @weekLabels
      datasets: [
        label: 'Number of posts',
        data: @postCounts
        borderWidth: 4
        borderColor: 'rgba(0,0,0,0.75)'
      ]
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
