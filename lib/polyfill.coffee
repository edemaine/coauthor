## Temporary until Meteor 3 / Node 20.
unless Array.prototype.at?
  Object.defineProperty Array.prototype, 'at',
    value: (index) ->
      index = Math.trunc index
      index += @length if index < 0
      @[index]
    configurable: true
    writable: true
