util = require("util")
EventEmitter = require("events").EventEmitter
redis = require("redis")
config = require("../config")
Redis = require("../lib/redis")

class Foreman extends EventEmitter
  init: (callback) =>
    @redis_key = "distillery:" + process.env.NODE_ENV + ":msg_queue"
    Redis.getClient (err, client) =>
      @local_redis = client
      callback(err, client)

  connect: (callback) =>
    @connectRedis()
    @startProcessing()

  connectRedis: =>
    @redis_client = redis.createClient(config.msg_source_redis.port, config.msg_source_redis.host)
    @redis_client.select config.msg_source_redis.db_num  if config.msg_source_redis.db_num
    console.log "Redis connected."
    @redis_client.once "end", =>
      console.log "Lost connection to Redis. Reconnecting..."
      @connectRedis()

  terminate: ->

  startProcessing: =>
    @redis_client.brpop @redis_key, 0, (err, reply) =>
      if err?
        console.error "Error during Redis BRPOP: " + err
        @startProcessing()
      else
        list = reply[0]
        message = reply[1]
        @handleMessage message

  handleMessage: (json_msg) =>
    try
      @processMessage JSON.parse(json_msg)
      @local_redis.set "whistlepunk:last_event_processed", json_msg
    catch err
      console.log "Error processing message:" + json_msg + "; error was " + err
    finally
      @startProcessing()

  processMessage: (message) =>
    @emit message.eventName, message
    console.log message.eventName, message  if process.env.NODE_ENV is "development"

module.exports = Foreman