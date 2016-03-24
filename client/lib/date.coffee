@formatDate = (date, prefix = '') ->
  return '???' unless date?
  return "?#{date}?" unless date instanceof Date  ## have seen this briefly, not sure when
  now = new Date()
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
  if date.getFullYear() == now.getFullYear()
    if date.getMonth() == now.getMonth() and date.getDate() == now.getDate()
      "today at #{time}"
    else
      now.setDate now.getDate()-1
      if date.getMonth() == now.getMonth() and date.getDate() == now.getDate()
        "yesterday at #{time}"
      else
        "#{prefix}#{date.toLocaleDateString 'en-US', options} at #{time}"
  else
    options.year = 'numeric'
    "#{prefix}#{date.toLocaleDateString 'en-US', options} at #{time}"

Template.registerHelper 'formatDate', (date, kw) ->
  formatDate date, kw?.hash?.prefix
