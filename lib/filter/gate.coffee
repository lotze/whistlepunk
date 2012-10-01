Stream = require 'stream'

class Gate extends Stream
  constructor: (@discriminator) ->
    super()
    @readable = true
    @writable = true

  write: (event) =>
    @emit 'data', event if @discriminator(event)

  end: (event) =>
    @write event if event?
    @emit 'end'
    @destroy()

  destroy: =>
    @writable = false
    @readable = false
    @emit 'close'

module.exports = Gate
