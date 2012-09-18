ReconnectingRedis = require("./reconnecting_redis")
config = require("../config")

module.exports = (env, server, cb) ->
  redis_config = switch server
    when 'whistlepunk' then config.filtered_redis
    when 'distillery' then config.unfiltered_redis
    else config.redis

  client = new ReconnectingRedis(redis_config.host, redis_config.port, redis_config.db_num)
  client.connect cb