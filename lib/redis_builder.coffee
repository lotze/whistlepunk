ReconnectingRedis = require("./reconnecting_redis")
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

  client = new ReconnectingRedis(redis_config.host, redis_config.port, redis_config.db_num)
  if cb?
    client.connect cb
  else
    client.connect()
