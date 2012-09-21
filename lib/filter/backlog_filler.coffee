Stream = require 'stream'

# BacklogFiller is a writable stream that places incoming events into the
# Redis backlog. It applies backpressure if the number of incoming events
# build up faster than it can push them into Redis.
class BacklogFiller extends Stream
  constructor: (@redis) ->
    super()
    @writable = true
    @key = 'event:' + process.env.NODE_ENV + ':backlog'
    @pendingWrites = 0

  write: (event) =>
    @pendingWrites++
    json = JSON.parse(event)
    timestamp = json.timestamp
    @redis.zadd @key, timestamp, event, =>
      @pendingWrites--
      @emit 'added', event

    # Backpressure handling--slow down incoming events if we're getting backed up
    if @pendingWrites >= 1000
      return false
    if @pendingWrites <= 0
      @emit 'drain'

  end: (event) =>
    if event?
      @write(event)
    @destroy()

  destroySoon: =>
    return unless @writable
    @writable = false
    # After the last pending write goes out, disconnect from Redis
    if @pendingWrites > 0
      @on 'added', =>
        @destroy() if @pendingWrites <= 0
    else
      @destroy()

  destroy: =>
    @writable = false
    @redis.quit()
    @emit 'close'

module.exports = BacklogFiller