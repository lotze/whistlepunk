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
    when 'filtered' then config.filtered_redis
    when 'distillery' then config.unfiltered_redis
    when 'whistlepunk' then config.redis
    else throw new Error("#{server} is not a valid server for redis_builder")

  client = redis.createClient redis_config.port, redis_config.host

  # Handle Redis errors here so that the client will automatically reconnect [BT]
  client.on 'error', (err) ->
    console.error "Error in Redis client: #{err.stack}"

  # client.select will cause the client to automatically re-select
  # the same DB in the case of a reconnect [BT]
  client.select redis_config.db_num if redis_config.db_num?
  cb(client) if cb?
  client
