Stream = require 'stream'

class Gate extends Stream
  constructor: (@discriminator) ->
    super()
    @readable = true
    @writable = true

  write: (event) =>
    @emit 'data', event if @discriminator(event)

  end: (event) =>
    @write event
    @destroy()

  destroy: =>
    @writable = false
    @emit 'close'

module.exports = Gate
