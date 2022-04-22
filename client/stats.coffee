import React, {useEffect, useMemo, useRef} from 'react'
import Dropdown from 'react-bootstrap/Dropdown'
import {useTracker} from 'meteor/react-meteor-data'
import Blaze from 'meteor/gadicc:blaze-react-component'
import dayjs from 'dayjs'

import {ErrorBoundary} from './ErrorBoundary'
import {TextTooltip} from './lib/tooltip'
import {UserLink} from './UserLink'

statsUnits =
  hour: 'Hour'
  weekday: 'Day of week'
  day: 'Day'
  week: 'Week'
  month: 'Month'
  year: 'Year'
defaultUnit = 'week'

daysOfWeek = [ # do not change this order; used for internal representation
  'Sunday'
  'Monday'
  'Tuesday'
  'Wednesday'
  'Thursday'
  'Friday'
  'Saturday'
]
defaultWeekStart = 0  ## Sunday
groupWeekStart = (group) ->
  findGroup(group)?.weekStart ? defaultWeekStart

purple = (alpha) -> "rgba(102,51,153,#{alpha})"
#blue = (alpha) -> "rgba(5,141,199,#{alpha})"

Template.stats.helpers
  MaybeStats: -> MaybeStats

Chart = null  # eventually Chart.js

export MaybeStats = React.memo (props) ->
  {group} = props
  groupData = useTracker ->
    findGroup group
  , [group]

  if groupData?
    <ErrorBoundary>
      <Stats {...props}/>
    </ErrorBoundary>
  else
    <Blaze template="badGroup" group={group}/>
MaybeStats.displayName = 'MaybeStats'

export Stats = React.memo ({group, username, unit}) ->
  unit ?= defaultUnit
  username = Meteor.user()?.username if username == 'me'
  useEffect ->
    title = "Statistics"
    title += " for #{username}" if username
    setTitle title
    undefined
  , []
  superuser = useTracker ->
    canSuper group
  , [group]
  weekStart = useTracker ->
    groupWeekStart group
  , [group]

  ## Initialize `stats` object (re-used throughout lifetime)
  stats = useMemo ->
    s = [
      type: 'user'
      query: -> messagesByQuery(group, username, false)
      datasets: [
        msgFilter: (msg) -> username in msg.coauthors
        label: 'Coauthored posts'
        borderWidth: 4
        colorFunc: purple
      #,
      #  msgFilter: (msg) -> atMentioned msg, username
      #  label: 'Posts that @-mention user'
      #  borderWidth: 4
      #  colorFunc: blue
      ]
    ,
      type: 'global'
      query: ->
        group: group
        published: $ne: false
        deleted: $ne: true
      datasets: [
        label: 'All posts',
        borderWidth: 4
        colorFunc: purple
      ]
    ]
    for dataset in _.flatten (stat.datasets for stat in s), true
      dataset.borderColor = dataset.colorFunc 0.6
      dataset.backgroundColor = dataset.colorFunc 0.1
    s
  , [group, username]
  ## Compute actual statistics, updating with subscription
  updated = useTracker ->
    unless Chart?
      Session.set 'ChartLoading', true
      Session.get 'ChartLoading'
      import('chart.js').then (mod) ->
        Chart = mod
        Chart.defaults.global.hover.intersect = false
        Chart.defaults.global.hover.mode = 'index'
        Chart.defaults.global.tooltips.intersect = false
        Chart.defaults.global.tooltips.mode = 'index'
        Session.set 'ChartLoading', false
      return
    for stat in stats
      continue if stat.type == 'user' and not username?
      buildStats stat, unit, weekStart
    new Date
  , [stats, unit, weekStart]
  canvasRefs = (useRef() for i in [0, 1])
  useEffect ->
    return unless updated?
    for stat, i in stats
      continue if stat.type == 'user' and not username?
      if stat.chart?
        stat.chart.update 1000
      else
        stat.chart = new Chart.Chart canvasRefs[i].current,
          type: 'line'
          data: stat
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
  , [updated]
  ready = useTracker ->
    Router.current().ready()
  , []

  onUnit = (e) ->
    e.preventDefault()
    Router.go Router.current().route.getName(), Router.current().params,
      query:
        unit: e.target.getAttribute 'data-unit'
  onWeekStart = (e) ->
    e.preventDefault()
    Meteor.call 'groupWeekStart', group, parseInt e.target.getAttribute 'data-day'
  onTSV = (e) ->
    e.preventDefault()
    tsvStats =
      type: 'users'
      query: -> #messagesByQuery(group, username, false)
        group: group
        published: $ne: false
        deleted: $ne: true
      datasets: [
        fullname: 'ALL MESSAGES'
      ].concat Meteor.users.find({}, sort: username: 1).map (user) ->
        username: user.username
        fullname: user.profile?.fullname
        member: if fullMemberOfGroup group, user then 'full' else 'partial'
        email: user.emails?[0]?.address
        msgFilter: (msg) -> user.username in msg.coauthors
    buildStats tsvStats, unit, weekStart
    rows = [['Username', 'Fullname', 'Email', 'Membership', 'Total'].concat tsvStats.labels]
    for dataset in tsvStats.datasets
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
    filename = "#{group}-#{unit}.tsv"
    (await import('file-saver')).saveAs blob, filename

  <>
    <h1>
      Statistics by
      {' '}
      <div className="btn-group">
        <Dropdown>
          <Dropdown.Toggle size="lg" variant="primary"> 
            {capitalize statsUnits[unit]}
            {' '}
            <span className="caret"/>
          </Dropdown.Toggle>
          <Dropdown.Menu>
            {for unitKey, unitTitle of statsUnits
              <li key={unitKey} className={if unit == unitKey then 'active'}>
                <Dropdown.Item href="#" data-unit={unitKey} onClick={onUnit}>
                  {unitTitle}
                </Dropdown.Item>
              </li>
            }
          </Dropdown.Menu>
        </Dropdown>
      </div>
      {if unit == 'week'
        <>
          <span className="small"> starting on </span>
          {if superuser
            <div className="btn-group">
              <Dropdown>
                <Dropdown.Toggle size="lg" variant="danger">
                  {daysOfWeek[weekStart]}
                  {' '}
                  <span className="caret"/>
                </Dropdown.Toggle>
                <Dropdown.Menu>
                  {for day, index in daysOfWeek
                    <li key={index} className="weekStart #{if weekStart == index then 'active' else ''}">
                      <Dropdown.Item href="#" data-day={index}
                       onClick={onWeekStart}>
                        {day}
                      </Dropdown.Item>
                    </li>
                  }
                </Dropdown.Menu>
              </Dropdown>
            </div>
          else
            <span className="small">{daysOfWeek[weekStart]}</span>
          }
        </>
      }
    </h1>
    {if username?
      <>
        <h2>
          <UserLink group={group} username={username}/>
          &rsquo;s Statistics: {stats[0].msgCount} posts
        </h2>
        <canvas className="userStats" width="800" height="400" ref={canvasRefs[0]}/>
      </>
    }
    <h2>
      Global Statistics: {stats[1].msgCount} posts
    </h2>
    <canvas className="globalStats" width="800" height="400" ref={canvasRefs[1]}/>
    <p/>
    {if ready
      <button className="btn btn-default downloadTSV" onClick={onTSV}>
        Download TSV
      </button>
    else
      <TextTooltip title="Please wait for all messages to load before downloading TSV.">
        <button className="btn btn-default downloadTSV disabled">
          Download TSV
          <span className="fas fa-spinner fa-spin"/>
        </button>
      </TextTooltip>
    }
    <hr/>
    <p className="small">
      * Data represents <b>undeleted</b>, <b>published</b> messages <b>visible to you</b>. Messages are plotted according to their <b>creation date</b>.
    </p>
  </>
Stats.displayName = 'Stats'

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

buildStats = (stats, unit, weekStart) ->
  format = unitFormat unit
  stats.labels = []
  for dataset in stats.datasets
    dataset.data = []
  lastDate = null
  makeDay = ->
    stats.labels.push lastDate.format format
    for dataset in stats.datasets
      dataset.data.push 0
  msgs = Messages.find stats.query(),
    fields:
      created: true
      body: true
      title: true
      coauthors: true
    sort: created: 1
  stats.msgCount = msgs.count()
  switch unit
    when 'hour'
      msgs = _.sortBy msgs.fetch(), (msg) -> dayjs(msg.created).format 'HH:mm'
    when 'weekday'
      msgs = _.sortBy msgs.fetch(), (msg) -> dayjs(msg.created).day()
  msgs.forEach (msg) ->
    increment = unit
    switch unit
      when 'week'
        day = dayjs(msg.created).startOf 'day'
        if day.day() < weekStart
          day = day.day -7 + weekStart  ## previous week
        else
          day = day.day weekStart  ## same week
      when 'hour'
        day = dayjs msg.created
        .startOf unit
        .year 2000
        .month 0
        .date 1
      when 'weekday'
        day = dayjs msg.created
        .startOf 'day'
        .date 1 + dayjs(msg.created).day()
        .month 9
        .year 2000  ## 1st day of October 2000 is a Sunday
        increment = 'day'
      else
        day = dayjs(msg.created).startOf unit
    if lastDate?
      if lastDate.isAfter day
        console.warn "Backwards time travel from #{lastDate.format()} to #{day.format()}"
        lastDate = day
        makeDay()
      else
        until lastDate.isSame day
          lastDate = lastDate.add 1, increment
          makeDay()
          if lastDate.isAfter day
            console.warn "Bad day handling (Coauthor bug)"
            break
    else
      lastDate = day
      makeDay()
    for dataset in stats.datasets
      if dataset.msgFilter?
        continue unless dataset.msgFilter msg
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

## https://en.wikipedia.org/wiki/Tab-separated_values
escapeTSVmap =
  '\\': '\\\\'
  '\n': '\\n'
  '\t': '\\t'
  '\r': '\\r'
escapeTSVre = new RegExp "[#{(key for key of escapeTSVmap).join ''}]", 'g'
escapeTSV = (x) ->
  x.toString().replace escapeTSVre, (match) -> escapeTSVmap[match]
