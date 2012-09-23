Stream = require 'stream'

# Dispatcher is a readable stream that emits `data` events
# corresponding with entries on the Distillery message queue.
#
# Unlike file streams, Dispatcher will not emit an `end` event
# on its own. Instead, it will continue to try to stream until
# `destroy()` is called on it.
#
# Events:
#
#   data
#     The `data` event emits JSON-stringified version of an event.
#
# Methods:
#
#   destroy()
#     Destroys the stream, disconnecting from redis and sending the
#     appropriate `end` and `close` events.
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
          console.log '      emitting', reply
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
      @emit 'close'
      @redis = null

module.exports = Dispatcher
