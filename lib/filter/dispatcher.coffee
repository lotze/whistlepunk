Stream = require 'stream'

# Dispatcher is a readable stream that emits data events
# corresponding with entries on the Distillery message queue.
# The Redis client passed in to the construtor should not be
# shared, as it executes a BRPOP, blocking the client.
#
# Events:
#
#   data
#     The `data` event emits JSON-stringified version of an event.
class Dispatcher extends Stream

  constructor: (@redis) ->
    super()
    @readable = true
    @streaming = false
    @resume()

  resume: =>
    return if @streaming
    @streaming = true
    @getFromRedis()

  pause: =>
    return unless @streaming
    @streaming = false

  getFromRedis: =>
    if @streaming
      # Note that, even though BRPOP is a blocking Redis command, it doesn't actually
      # block the Node.js event loop; instead, the callback to the BRPOP call simply
      # isn't executed until the Redis command returns. [BT]
      @redis.brpop "distillery:" + process.env.NODE_ENV + ":msg_queue", 0, (err, reply) =>
        if err?
          @emit('error', err)
        else
          [list, data] = reply
          @emit('data', data)
        @getFromRedis()

module.exports = Dispatcher
