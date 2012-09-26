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
    return @emit 'error', new Error('stream is not writable') unless @writable
    @queue.push event
    @flush()
    false

  flush: =>
    return if @busy
    if @queue.length == 0
      @emit 'drain'
      return

    @busy = true
    eventJson = @queue.shift()

    # This is a point of entry for external data, hence a try/catch
    # to prevent exceptions that kill the node process on invalid JSON
    try
      event = JSON.parse eventJson
    catch error
      console.error "Problem parsing JSON in BacklogFiller#flush: #{error} in #{eventJson}"
      @busy = false
      @flush()
      return

    timestamp = event.timestamp
    @redis.zadd @key, timestamp, eventJson, (err) =>
      @emit 'error', err if err?
      @emit 'added', event
      @busy = false
      @flush()

  end: (event) =>
    if event?
      @write(event)
    @destroySoon()

  destroySoon: =>
    return unless @writable
    @writable = false
    # After the last pending write goes out, disconnect from Redis
    if @queue.length > 0
      @on 'added', =>
        @destroy() if @queue.length == 0
    else
      @destroy()

  destroy: =>
    return unless @redis?
    @writable = false
    @redis.quit =>
      @redis = null
      @emit 'close'

module.exports = BacklogFiller
