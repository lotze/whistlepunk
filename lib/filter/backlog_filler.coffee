Stream = require 'stream'

# BacklogFiller is a writable stream that places incoming events into the
# Redis backlog. It applies backpressure if the number of incoming events
# build up faster than it can push them into Redis.
class BacklogFiller extends Stream
  constructor: (@redis) ->
    super()
    @writable = true
    @key = 'event:' + process.env.NODE_ENV + ':backlog'
    @queue = []

  write: (event) =>
    @emit 'error', new Error('stream is not writable') unless @writable
    @queue.push event
    @flush()
    false

  flush: =>
    return if @busy
    if @queue.length == 0
      @emit 'drain'
      return

    @busy = true
    event = @queue.shift()
    json = JSON.parse(event)
    timestamp = json.timestamp
    @redis.zadd @key, timestamp, event, =>
      @emit 'added', event
      @busy = false
      @flush()

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
