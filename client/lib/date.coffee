@formatDate = (date, prefix = '', absolute) ->
  return '???' unless date?
  return "?#{date}?" unless date instanceof Date  ## have seen this briefly, not sure when
  now = new Date
  options =
    weekday: 'short'
    month: 'short'
    day: 'numeric'
  #mdate = moment date
  #time = mdate.format 'LT'
  time = date.getHours() + ':'
  if date.getMinutes() < 10
    time += '0'
  time += date.getMinutes()
  if date.getFullYear() == now.getFullYear() and not absolute
    if date.getMonth() == now.getMonth() and date.getDate() == now.getDate()
      Session.get 'today'  # depend on the current date; see below
      "today at #{time}"
    else
      now.setDate now.getDate()-1
      if date.getMonth() == now.getMonth() and date.getDate() == now.getDate()
        Session.get 'today'  # depend on the current date; see below
        "yesterday at #{time}"
      else
        "#{prefix}#{date.toLocaleDateString 'en-US', options} at #{time}"
  else
    options.year = 'numeric'
    "#{prefix}#{date.toLocaleDateString 'en-US', options} at #{time}"

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