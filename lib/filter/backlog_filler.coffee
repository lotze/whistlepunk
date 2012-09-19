{EventEmitter} = require 'events'

class BacklogFiller extends EventEmitter
  constructor: (dispatcher, @redis) ->
    super()
    @key = 'event:' + process.env.NODE_ENV + ':backlog'
    dispatcher.on 'data', @storeInBacklog

  storeInBacklog: (event) =>
    json = JSON.parse(event)
    timestamp = json.timestamp
    @redis.zadd @key, timestamp, event, =>
      @emit 'added', event

module.exports = BacklogFiller