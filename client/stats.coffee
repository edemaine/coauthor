import Chart from 'chart.js'

purple = (alpha) -> "rgba(102,51,153,#{alpha})"

Template.statsGood.onCreated ->
  @labels = []
  @postCounts = []
  @pointColors = []
  @autorun =>
    @labels.splice 0, @labels.length
    @postCounts.splice 0, @postCounts.length
    @pointColors.splice 0, @pointColors.length
    lastDay = null
    makeDay = =>
      @labels.push lastDay.format 'ddd, MMM DD, YYYY' #'YYYY-MM-DD'
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
    for count, i in @postCounts
      if count == 0
        @pointColors.push 'red'
      else
        @pointColors.push purple 1
    @chart?.update 1000

Template.statsGood.onRendered ->
  @chart = new Chart @find('.yourStats'),
    type: 'line'
    data:
      labels: @labels
      datasets: [
        label: 'Authored posts',
        data: @postCounts
        borderWidth: 4
        borderColor: purple 0.7
        backgroundColor: purple 0.1
        #borderColor: 'rgba(5,141,199,0.9)'
        #backgroundColor: 'rgba(5,141,199,0.1)'
        pointBorderColor: @pointColors
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
