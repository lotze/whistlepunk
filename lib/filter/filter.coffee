_ = require 'underscore'
Stream = require 'stream'

class Filter extends Stream
  constructor: (@redis, @validators, @delta) ->
    super()
    @pendingWrites = 0
    @on 'doneProcessing', => @pendingWrites--
    @key = "event:" + process.env.NODE_ENV + ":valid_users"

  write: (eventJson) =>
    @pendingWrites++
    event = JSON.parse(eventJson)

    # Wipe user records older than @delta from Reddis
    # TODO: Optimize. Shouldn't run with each write call
    @redis.zremrangebyscore @key, 0, event.timestamp - @delta

    if _.all(@validators, (validator) -> validator.isValid(event))
      @redis.zscore @key, event.userId, (err, reply) =>
        console.log err if err?
        timestamp = parseInt reply, 10
        if !timestamp || timestamp < event.timestamp
          @redis.zadd @key, event.timestamp, event.userId, =>
            @emit 'doneProcessing'
        else
          @emit 'doneProcessing'
    else
      @emit 'doneProcessing'

    if @pendingWrites >= 1000
      return false
    if @pendingWrites <= 0
      @emit 'drain'

  end: (eventJson) =>
    @write eventJson
    @destroySoon()

  destroy: =>
    @writable = false
    @redis.quit()
    @emit 'close'

  destroySoon: =>
    @writable = false
    if @pendingWrites > 0
      @on 'doneProcessing', =>
        @destroy() if @pendingWrites <= 0
    else
      @destroy()

module.exports = Filter