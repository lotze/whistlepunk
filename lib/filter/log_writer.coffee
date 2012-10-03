Stream = require 'stream'
fs = require 'fs'

class LogWriter extends Stream
  constructor: (@filename) ->
    super()
    @writable = true
    @stream = fs.createWriteStream(@filename, {'flags': 'a'})
    @stream.on 'drain', => @emit 'drain'
    @stream.on 'error', (err) => @emit 'error', err # TODO: Better error handling [BT/TL]

  write: (eventJson) =>
    success = @stream.write(eventJson + "\n")
    @emit 'doneProcessing'
    success

  end: (eventJson) =>
    @write eventJson if eventJson?
    @destroy()

  destroy: =>
    @writable = false
    @stream.on 'close', => @emit 'close'
    @stream.destroySoon()

module.exports = LogWriter
