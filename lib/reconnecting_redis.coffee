redis = require('redis')

class ReconnectingRedis
  constructor: (@host, @port, @dbnum) ->

  connect: (cb) =>
    @client = redis.createClient(@port, @host)
    @client.select @dbnum if @dbnum
    # console.log "Redis connected: #{@host}:#{@port}/#{@dbnum}."
    @client.once "end", =>
      console.log "Lost connection to Redis: #{@host}:#{@port}/#{@dbnum}. Reconnecting..."
      @connect()
    cb(null, @client) if cb?

module.exports = ReconnectingRedis
