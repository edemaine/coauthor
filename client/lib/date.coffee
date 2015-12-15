@formatDate = (date, prefix = 'on ') ->
  return '???' unless date?
  return "?#{date}?" unless date instanceOf Date  ## have seen this briefly, not sure when
  now = new Date()
  options =
    weekday: 'long'
    month: 'long'
    day: 'numeric'
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

Template.registerHelper 'formatDate', (date) ->
  formatDate date
