Stream = require 'stream'

class Dispatcher extends Stream
  constructor: (@redis) ->
    super()
    @key = "distillery:" + process.env.NODE_ENV + ":msg_queue"
    @readable = true
    @paused = true
    @processing = false
    @resume()

  resume: =>
    return unless @paused
    @paused = false
    @getFromRedis() unless @processing

  pause: =>
    @paused = true

  getFromRedis: =>
    if !@paused && !@processing && @readable
      @processing = true
      # We want to make sure we read off the entire queue of events at once, so that when the stream
      # is destroyed, we can be sure that there are no extra events sitting around in the Distillery
      # message queue. The problem with this is, if there is a large backlog of events in the message
      # queue, they will all be loaded into RAM at once. [BT]
      multi = @redis.multi()
      multi.lrange @key, 0, -1
      multi.del @key
      multi.exec (err, replies) =>
        @processing = false
        if err?
          @emit('error', err)
        else if replies?
          [reply, deleteSuccess] = replies
          # TODO: Log how many events are in the `reply`.
          if reply? && reply.length
            # `reply` is reversed due to using LRANGE 0, -1 and the fact that Distillery is LPUSH'd into
            # (e.g. the oldest/first event is on the right of the list) [BT]
            @emit 'data', event for event in reply.reverse()
          @emit 'doneProcessing'
          process.nextTick @getFromRedis

  destroy: =>
    if @processing
      @once 'doneProcessing', =>
        @once 'doneProcessing', @_shutdown
    else
      @once 'doneProcessing', @_shutdown

  _shutdown: =>
    @readable = false
    @redis.quit =>
      @redis = null
      @emit 'end'
      @emit 'close'

module.exports = Dispatcher
