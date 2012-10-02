Stream = require 'stream'

# **BacklogFiller** is a duplex stream that takes data written to it and places
# it in a Redis backlog for later processing. Once the data has been successfully
# written to Redis, it will emit a `data` even with the same data.
#
# BacklogFiller adds the events to a Redis sorted set, with the `timestamp` attribute of
# the event used as the score for the entry.
class BacklogFiller extends Stream

  # Constructor
  # -----------
  #
  # Initialize a BacklogFiller.
  #
  # * redis - An instance of a Redis client to use for inserting into the backlog.
  constructor: (@redis) ->
    super()
    @writable = true
    @readable = false
    @key = 'event:' + process.env.NODE_ENV + ':backlog'
    @queue = []
    @parentStream = null
    # When we pipe a stream into BacklogFiller, we will store a reference to that stream
    # so that our `pause` and `resume` methods, and our `drain` events, are all delegated
    # to that stream.
    @on 'pipe', (stream) =>
      @readable = true
      @parentStream = stream
      @parentStream.on 'drain', => @emit 'drain'

  # Adds the given event JSON to the queue to be `flush`ed later. `json` **must** have a `timestamp`
  # property.
  write: (json) =>
    return @emit 'error', new Error('stream is not writable') unless @writable
    @queue.push json
    @flush()
    false

  pause: =>
    if @parentStream?
      @parentStream.pause()
    else
      @emit 'error', new Error('Cannot pause this stream unless another stream is piped into it first')

  resume: =>
    if @parentStream?
      @parentStream.resume()
    else
      @emit 'error', new Error('Cannot resume this stream unless another stream is piped into it first')

  # `flush` is called recusrively in order to drain the queue.
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
      @emit 'data', eventJson
      @busy = false
      @flush()

  end: (json) =>
    @write(json) if json?
    @destroySoon()

  destroySoon: =>
    return unless @writable
    @writable = false
    # After the last pending write goes out, disconnect from Redis
    if @queue.length > 0
      @on 'data', =>
        @destroy() if @queue.length == 0
    else
      @destroy()

  destroy: =>
    return unless @redis?
    @writable = false
    @redis.quit =>
      @redis = null
      @emit 'end'
      @emit 'close'

module.exports = BacklogFiller
