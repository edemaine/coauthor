## Upgrade from old file message format (format 'file', body = file pointer)
## to new file message format (file = file pointer)
Messages.find
  format: 'file'
.forEach (msg) ->
  Messages.update msg._id,
    $set:
      format: defaultFormat
      title: ''
      body: ''
      file: msg.body
MessagesDiff.find
  format: 'file'
.forEach (diff) ->
  MessagesDiff.update diff._id,
    $set:
      format: defaultFormat
      title: ''
      body: ''
      file: diff.body
