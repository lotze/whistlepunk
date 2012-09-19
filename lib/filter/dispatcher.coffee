Stream = require 'stream'

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
      @redis.brpop "distillery:test:msg_queue", 0, (err, reply) =>
        if err?
          @emit('error', err)
        else
          [list, data] = reply
          @emit('data', data)
        @getFromRedis()

module.exports = Dispatcher
