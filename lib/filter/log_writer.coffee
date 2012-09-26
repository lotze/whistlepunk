Stream = require 'stream'
fs = require 'fs'

class LogWriter extends Stream
  constructor: (@filename) ->
    super()
    @writable = true

  write: (eventJson) =>
    fs.appendFile @filename, eventJson + '\n', (err) =>
      console.error("Error appending to logs: " + err.stack) if err
      @emit 'doneProcessing'

  end: (eventJson) =>
    @write eventJson
    @destroy()

  destroy: =>
    @writable = false
    @emit 'close'

module.exports = LogWriter