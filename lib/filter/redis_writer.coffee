_ = require 'underscore'
Stream = require 'stream'

class RedisWriter extends Stream

  constructor: (@redis, @destination) ->
    super()
    @pendingWrites = 0
    @on 'doneProcessing', => @pendingWrites--
    @key = "event:" + process.env.NODE_ENV + ":" + @destination

  write: (eventJson) =>
    @pendingWrites++
    event = JSON.parse eventJson

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
    @redis.quit()
    @emit 'close'

  destroySoon: =>
    @writable = false
    if @pendingWrites > 0
      @on 'doneProcessing', =>
        @destroy() if @pendingWrites <= 0
    else
      @destroy()

module.exports = RedisWriter