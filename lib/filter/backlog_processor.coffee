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
    return true if @processing || @paused
    @processing = true
    event = JSON.parse(eventJson)
    @processEvents(event.timestamp)
    return true

  end: (eventJson) =>
    @write(eventJson)
    @destroySoon()

  destroy: =>
    @writable = false
    @redis.quit()
    @emit 'close'

  destroySoon: =>
    @writable = false
    @on 'doneProcessing', @destroy

  pause: =>
    return if @paused
    @paused = true

  resume: =>
    return unless @paused
    @paused = false

  processEvents: (timestamp) =>
    max = timestamp - @delta
    @redis.zrangebyscore @key, 0, max, (err, reply) =>
      if reply?
        async.forEach reply, @processEvent, (err) =>
          @processing = false
          @emit 'doneProcessing'

  processEvent: (event, callback) =>
    @filter.isValid event, (valid) =>
      @emit 'data', valid, event
      callback() if callback?

module.exports = BacklogProcessor