import React from 'react'
import {useTracker} from 'meteor/react-meteor-data'

monthDayFormat = new Intl.DateTimeFormat 'en-US',
  weekday: 'short'
  month: 'short'
  day: 'numeric'
monthDayYearFormat = new Intl.DateTimeFormat 'en-US',
  weekday: 'short'
  month: 'short'
  day: 'numeric'
  year: 'numeric'

export formatDateOnly = (date, prefix = '', absolute) ->
  return '???' unless date?
  return "?#{date}?" unless date instanceof Date  ## have seen this briefly, not sure when
  now = new Date
  if date.getFullYear() == now.getFullYear() and not absolute
    if date.getMonth() == now.getMonth() and date.getDate() == now.getDate()
      Session.get 'today'  # depend on the current date; see below
      "today"
    else
      now.setDate now.getDate()-1
      if date.getMonth() == now.getMonth() and date.getDate() == now.getDate()
        Session.get 'today'  # depend on the current date; see below
        "yesterday"
      else
        "#{prefix}#{monthDayFormat.format date}"
  else
    "#{prefix}#{monthDayYearFormat.format date}"

export formatDate = (date, prefix, absolute) ->
  dateOnly = formatDateOnly date, prefix, absolute
  return dateOnly if dateOnly.startsWith '?'
  time = date.getHours() + ':'
  if date.getMinutes() < 10
    time += '0'
  time += date.getMinutes()
  "#{dateOnly} at #{time}"

export FormatDate = React.memo ({date, prefix}) ->
  useTracker ->
    formatDate date, prefix
  , [date, prefix]
FormatDate.displayName = 'FormatDate'

Template.registerHelper 'formatDate', (date, kw) ->
  formatDate date, kw?.hash?.prefix

formatDateISO = (date) ->
  "#{date.getFullYear()}-#{date.getMonth()+1}-#{date.getDate()+1}"

###
Maintain the current date (year-month-day) in the Session variable 'today',
allowing the code above to reactively depend on the current date via
`Session.get 'today'`.
###
do maintainToday = ->
  now = new Date
  Session.set 'today', formatDateISO now
  tomorrow = new Date
  tomorrow.setDate tomorrow.getDate() + 1
  tomorrow.setHours 0
  tomorrow.setMinutes 0
  tomorrow.setSeconds 0, 0
  Meteor.setTimeout maintainToday, tomorrow - now
