Stream = require 'stream'

# **Dispatcher** is a readable stream that emits `data` events for every entry
# in the Distillery message queue. The message queue should be LPUSHed into--that is,
# the oldest event should be at the right end (higher index) of the Redis list.
#
# Unlike other Node.js streams you may be familiar with (such as most of the ones from
# the `fs` module), Dispatcher will not ever emit an `end` event on its own. Instead,
# it will continually emit `data` events as it finds new items in the message queue,
# until `destroy()` is called on it.
class Dispatcher extends Stream

  # Constructor
  # -----------
  #
  # Initialize a Dispatcher and immediately start reading from the message queue.
  #
  # * redis - An instance of a Redis client to use for reading from the message queue.
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

  # We call `getFromRedis` recursively (using `process.nextTick`) to continually read off the message
  # queue. We use the LRANGE Redis command to make sure we read off the entire queue of events without
  # missing any when the stream is `destroy()`ed. Reading too many items off the queue and bloating
  # memory is a concern, and a series of RPOPs or Lua scripting may solve this issue. [BT]
  getFromRedis: =>
    if !@paused && !@processing && @readable
      @processing = true
      # We read every item from the list and clear out the list atomically using Redis' MUTLI.
      multi = @redis.multi()
      multi.lrange @key, 0, -1
      multi.del @key
      multi.exec (err, replies) =>
        @processing = false
        if err?
          @emit('error', err)
        else if replies?
          [reply, deleteSuccess] = replies
          # TODO: Log how many events are in the `reply` to aid in debugging memory usage.
          if reply? && reply.length
            # `reply` is reversed due to using LRANGE 0, -1 and the fact that Distillery is LPUSH'd into
            # (e.g. the oldest/first event is on the right of the list). Note that in JavaScript, Array#reverse
            # mutates the array! [BT]
            reply.reverse()
            @emit 'data', event for event in reply
          @emit 'doneProcessing'
          process.nextTick @getFromRedis

  # `destroy` will ensure that one more read of the message queue is done before shutting down,
  # in order to prevent non-deterministic behavior in tests. [BT]
  destroy: =>
    console.log("dispatcher destroying now")
    if @processing
      console.log("dispatcher needs to finish processing")
      @once 'doneProcessing', =>
        console.log("dispatcher got one 'doneProcessing'")
        @once 'doneProcessing', =>
          console.log("dispatcher got a second 'doneProcessing'")
          @_shutdown()
    else
      @once 'doneProcessing', =>
        console.log("dispatcher got one and only 'doneProcessing'")
        @_shutdown()

  _shutdown: =>
    console.log("dispatcher shutting down")
    @readable = false
    @redis.quit =>
      @redis = null
      @emit 'end'
      @emit 'close'

module.exports = Dispatcher
