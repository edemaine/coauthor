@pluralize = (count, text) ->
  "#{count} #{text}#{if count != 1 then 's' else ''}"
