Stream = require 'stream'

class Dispatcher extends Stream
  constructor: (@redis) ->
    super()
    @key = "distillery:" + process.env.NODE_ENV + ":msg_queue"
    @readable = true
    @paused = true
    @resume()

  resume: =>
    return unless @paused
    @paused = false
    @getFromRedis()

  pause: =>
    @paused = true

  getFromRedis: =>
    if !@paused && @readable
      # Although a BRPOP could be used here to simplify logic (and it works
      # fine in Node.js without blocking the event loop), it makes it
      # impossible to cleanly disconnect in `destroy`. [BT]
      @redis.rpop @key, (err, reply) =>
        if err?
          @emit('error', err)
        else if reply?
          @emit('data', reply)
          @getFromRedis()
        else
          # If no data was found, schedule another check on the next
          # tick of the Node event loop. [BT]
          process.nextTick @getFromRedis

  destroy: =>
    return unless @readable && @redis?
    @readable = false
    @emit 'end'
    @redis.quit =>
      @redis = null
      @emit 'close'

module.exports = Dispatcher
