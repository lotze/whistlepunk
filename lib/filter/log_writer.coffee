Stream = require 'stream'
fs = require 'fs'

class LogWriter extends Stream
  constructor: (@filename) ->
    super()
    @writable = true

  write: (eventJson) =>
    stream = fs.createWriteStream(@filename, {'flags': 'a'})
    stream.on "error", (err) =>
      console.error("Error appending to logs: " + err.stack) if err
    if stream.write(eventJson + '\n')
      stream.destroySoon()
      @emit 'doneProcessing'
    else
      stream.on "drain", () =>
        stream.destroySoon()
        @emit 'doneProcessing'
    # fs.appendFile @filename, eventJson + '\n', (err) =>
    #   console.error("Error appending to logs: " + err.stack) if err
    #   @emit 'doneProcessing'

  end: (eventJson) =>
    @write eventJson if eventJson?
    @destroy()

  destroy: =>
    @writable = false
    @emit 'close'

module.exports = LogWriter
