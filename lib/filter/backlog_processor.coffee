Stream = require 'stream'
async = require 'async'

class BacklogProcessor extends Stream
  constructor: (@redis, @delta, @filter) ->
    super()
    @readable = true
    @writable = true
    @processing = false
    @key = 'event:' + process.env.NODE_ENV + ':backlog'

  write: (eventJson) =>
    if @paused
      return true
    @emit 'error', new Error("BacklogProcessor stream is not writable") unless @writable

    # This is a point of entry for external data, hence a try/catch
    # to prevent exceptions that kill the node process on invalid JSON
    try
      event = JSON.parse eventJson
    catch error
      console.error "Problem parsing JSON in BacklogProcessor#write: #{error.stack}"
      return true

    if @processing
      if (@queuedTimestamp && event.timestamp > @queuedTimestamp) || !@queuedTimestamp?
        @queuedTimestamp = event.timestamp
      return true

    @processEvents(event.timestamp)
    return true

  end: (eventJson) =>
    @write eventJson if eventJson?
    @destroySoon()

  destroy: =>
    @writable = false
    @readable = false
    @emit 'end'
    @redis.quit =>
      @redis = null
      @emit 'close'

  destroySoon: =>
    @writable = false
    if @processing
      @on 'doneProcessing', @destroy
    else
      @destroy()

  pause: =>
    return if @paused
    @paused = true

  resume: =>
    return unless @paused
    @paused = false

  processEvents: (timestamp) =>
    @processing = true
    max = timestamp - @delta
    @redis.zrangebyscore @key, 0, max, (err, reply) =>
      if err?
        console.error "Error with ZRANGEBYSCORE in BacklogProcessor#processEvents: #{err.stack}"
      else if reply?
        async.forEachSeries reply, @processEvent, (err) =>
          if @queuedTimestamp
            timestamp = @queuedTimestamp
            @queuedTimestamp = null
            @processEvents timestamp
          else
            @processing = false
            @emit 'doneProcessing'

  processEvent: (eventJson, callback) =>
    @filter.isValid eventJson, (valid) =>
      event = JSON.parse eventJson
      event.isValidUser = valid
      eventJson = JSON.stringify event
      @emit 'data', eventJson
      callback() if callback?

module.exports = BacklogProcessor
