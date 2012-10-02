Stream = require 'stream'

class BacklogFiller extends Stream
  constructor: (@redis) ->
    super()
    @writable = true
    @readable = false
    @key = 'event:' + process.env.NODE_ENV + ':backlog'
    @queue = []
    @parentStream = null
    @on 'pipe', (stream) =>
      @readable = true
      @parentStream = stream
      @parentStream.on 'drain', => @emit 'drain'

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
      console.log ' ######## added', eventJson
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
      @emit 'close'

module.exports = BacklogFiller
