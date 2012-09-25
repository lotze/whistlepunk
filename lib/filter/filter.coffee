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
    event = JSON.parse(eventJson)

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
        console.log err if err?
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
    @redis.quit()
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
      console.log err if err?
      if reply?
        userScore = parseInt reply, 10
        now = event.timestamp
        pastExpirePoint = now - @backwardDelta
        futureExpirePoint = now + @forwardDelta
        console.log "Filter.isValid: " + event.userId + ": " + @to_s(pastExpirePoint) + " : " + @to_s(userScore) + " : " + @to_s(futureExpirePoint) + " : " + @backwardDelta + " : " + @forwardDelta
        if pastExpirePoint <= userScore <= futureExpirePoint
          return callback true
        else
          callback false
      else
        callback false

  to_s: (timestamp) ->
    date = new Date(timestamp)
    date.toString()

module.exports = Filter