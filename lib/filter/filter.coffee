_ = require 'underscore'
Stream = require 'stream'
async = require 'async'

class Filter extends Stream
  constructor: (@redis, @validators, @backwardDelta, @forwardDelta) ->
    super()
    @writable = true
    @pendingWrites = 0
    @on 'doneProcessing', => @pendingWrites--
    @key = "event:" + process.env.NODE_ENV + ":valid_users"

  write: (eventJson) =>
    @pendingWrites++

    # This is a point of entry for external data, hence a try/catch
    # to prevent exceptions that kill the node process on invalid JSON
    try
      event = JSON.parse eventJson
    catch error
      console.error "Problem parsing JSON in Filter#write: #{error.stack}"
      return true

    # Wipe user records older than @delta from Reddis
    # TODO: Optimize. Shouldn't run with each write call
    @redis.zremrangebyscore @key, 0, event.timestamp - @backwardDelta

    passesValidation = false
    for validator in @validators
      result = validator.validates eventJson
      if result
        passesValidation = true
      if validator.required && !result
        passesValidation = false
        break

    if passesValidation
      @redis.zscore @key, event.userId, (err, reply) =>
        if err?
          console.error "Error with ZSCORE in Filter#write: #{err.stack}"
          return @emit 'doneProcessing' # should do more error handing here?

        timestamp = parseInt reply, 10
        if !timestamp || timestamp < event.timestamp
          if event.eventName == 'loginGuidChange'
            async.parallel [
              @redis.zadd.bind(@redis, @key, event.timestamp, event.userId)
              @redis.zadd.bind(@redis, @key, event.timestamp, event.oldGuid)
              @redis.zadd.bind(@redis, @key, event.timestamp, event.newGuid)
            ], =>
              @emit 'doneProcessing'
          else
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
    @redis.quit =>
      @redis = null
      @emit 'close'

  destroySoon: =>
    @writable = false
    if @pendingWrites > 0
      @on 'doneProcessing', =>
        @destroy() if @pendingWrites <= 0
    else
      @destroy()

  isValid: (eventJson, callback) =>
    event = JSON.parse(eventJson)
    @redis.zscore @key, event.userId, (err, reply) =>
      if err?
        console.error err.stack
        callback false
      else if reply?
        callback true
      else
        callback false

  to_s: (timestamp) ->
    date = new Date(timestamp)
    date.toString()

module.exports = Filter
