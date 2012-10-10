Stream = require 'stream'
async = require 'async'

# BacklogProcessor is a duplex stream. Whenever an event is written to it
# via `write`, it checks the Redis backlog for any events created up to a
# point in time sometime before the timestamp on the event being written (based
# on the `delta` parameter passed into its constructor). For every event found,
# it will check its filter to see if the user associated with the event has been
# confirmed to be a "real" (non-bot) user or not. It then sets the `isValidUser`
# attribute on the event, determined by the check on the filter, and emits a
# JSON representation of the event with a `data` event.
#
# This stream is a bit different on its write method in that, other than the
# timestamp of the event, it does not actually care about the event being
# written--write is simply used as a trigger to kick off a process that reads
# a set of old records from Redis. write may not trigger another process in
# this way if an older bactch process is still running. Thus, the stream
# applies no backpressure (as it will simply discard superfluous events).
class BacklogProcessor extends Stream

  # Constructor
  # -----------
  #
  # Initialize a BacklogProcessor.
  #
  # * redis - An instance of a Redis client to use for reading from the backlog.
  # * delta - How far back to limit events that are processed when an event comes in via `write`.
  #   For example, a delta of one hour will cause a process to look for any events up to 5:00 PM
  #   if the event sent to `write` has a timestamp of 6:00 PM.
  # * filter - An instance of Filter to use to check for valid users.
  constructor: (@redis, @delta, @filter, @checker) ->
    super()
    @readable = true
    @writable = true
    @processing = false
    @key = 'event:' + process.env.NODE_ENV + ':backlog'

  # Triggers (or schedules, if busy processing) a process that reads backlogged events with
  # timestamps up to now-minus-delta ago.
  write: (eventJson) =>
    if @paused
      return true
    @emit 'error', new Error("BacklogProcessor stream is not writable") unless @writable

    # This is a point of entry for external data, hence a try/catch
    # to prevent exceptions that kill the node process on invalid JSON
    try
      event = JSON.parse eventJson
    catch error
      console.error "Problem parsing JSON in BacklogProcessor#write: #{error.stack}"
      return true

    # If we're already processing, we want to make sure to keep track of the written event
    # with the largest timestamp, so that when we're done processing we can process
    # again starting at that new timestamp. This is to ensure we don't miss any events
    # by accident, causing non-deterministic behavior, especially in tests. [BT]
    if @processing
      if (@queuedTimestamp && event.timestamp > @queuedTimestamp) || !@queuedTimestamp?
        @queuedTimestamp = event.timestamp
      return true

    @processEvents(event.timestamp)
    return true

  end: (eventJson) =>
    @write eventJson if eventJson?
    @destroySoon()

  _shutdown: =>
    @writable = false
    @readable = false
    @emit 'end'
    @redis.quit =>
      @checker.destroy()
      @redis = null
      @emit 'close'

  destroySoon: =>
    console.log("backlog processor destroying soon")
    @destroy()

  destroy: =>
    console.log("backlog processor destroying now")
    @writable = false
    if @processing
      @on 'doneProcessing', @_shutdown
    else
      @_shutdown()

  pause: =>
    return if @paused
    @paused = true

  resume: =>
    return unless @paused
    @paused = false

  processEvents: (timestamp) =>
    @processing = true
    max = timestamp - @delta
    #console.log("processing events in #{@key} from 0 to #{max} via ",@redis)
    @redis.zrangebyscore @key, 0, max, (err, reply) =>
      if err?
        console.error "Error with ZRANGEBYSCORE in BacklogProcessor#processEvents: #{err.stack}"
      else if reply?
        #console.log("Got #{reply.length} events to process")
        async.forEachSeries reply, @processEvent, (err) =>
          @redis.zremrangebyscore @key, 0, max, (err, reply) =>
            if err?
              console.error "Error removing old events in BacklogProcessor#processEvents: #{err.stack}"
            if @queuedTimestamp
              timestamp = @queuedTimestamp
              @queuedTimestamp = null
              @processEvents timestamp
            else
              @processing = false
              @emit 'doneProcessing'

  processEvent: (eventJson, callback) =>
    @checker.isValid eventJson, (valid) =>
      event = JSON.parse eventJson
      event.isValidUser = valid
      eventJson = JSON.stringify event
      @emit 'data', eventJson
      callback() if callback?

module.exports = BacklogProcessor
