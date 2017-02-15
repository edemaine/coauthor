import Chart from 'chart.js'

Template.statsGood.onCreated ->
  @weekLabels = []
  @postCounts = []
  @autorun =>
    @weekLabels.splice 0, @weekLabels.length
    @postCounts.splice 0, @postCounts.length
    Messages.find messagesByQuery Template.currentData().group, Meteor.user().username
    , sort: created: 1
    .forEach (msg) =>
      day = moment(msg.created).format 'YYYY-MM-DD'
      if @weekLabels.length > 0 and @weekLabels[@weekLabels.length-1] == day
        @postCounts[@postCounts.length-1] += 1
      else
        @weekLabels.push day
        @postCounts.push 1
    @chart?.update()

Template.statsGood.onRendered ->
  @chart = new Chart @find('.yourStats'),
    type: 'bar'
    data:
      labels: @weekLabels
      datasets: [
        label: 'Number of posts',
        data: @postCounts
        borderWidth: 1
      ]
    options:
      scales:
        yAxes: [
          ticks:
            beginAtZero: true
        ]
