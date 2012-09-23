redis = require 'redis'
config = require("../config")

module.exports = (env, server, cb) ->
  # called with (server, cb)
  if arguments.length == 2 && typeof server == 'function'
    cb = server
    server = env
    env = process.env.NODE_ENV
  # called with (server)
  else if arguments.length == 1
    server = env
    env = process.env.NODE_ENV

  redis_config = switch server
    when 'whistlepunk' then config.filtered_redis
    when 'distillery' then config.unfiltered_redis
    else config.redis

  client = redis.createClient redis_config.port, redis_config.host
  # Handle Redis errors here so that the client will automatically reconnect [BT]
  client.on 'error', (err) ->
    console.error "[ERR] Error in Redis client:"
    console.error err.stack
  # client.select will cause the client to automatically re-select
  # the same DB in the case of a reconnect [BT]
  client.select redis_config.db_num if redis_config.db_num?
  cb(client) if cb?
  client
