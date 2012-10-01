_ = require 'underscore'
Stream = require 'stream'

class RedisWriter extends Stream

  constructor: (@redis) ->
    super()
    @writable = true
    @pendingWrites = 0
    @on 'doneProcessing', => @pendingWrites--

  write: (eventJson) =>
    @pendingWrites++
    event = JSON.parse eventJson

    if event.isValidUser
      destination = "valid_users"
    else
      destination = "invalid_users"

    @key = "event:" + process.env.NODE_ENV + ":" + destination

    @redis.lpush @key, eventJson, =>
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

module.exports = RedisWriter
