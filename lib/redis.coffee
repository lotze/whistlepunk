redis = require('redis')
config = require('../config')

client = null

module.exports =
  getClient: (callback) =>
    if client?
      callback(null, client)
    else
      client = redis.createClient(config.redis.port, config.redis.host)
      client.on "error", (err) ->
        console.log("Error " + err);
      client.once "ready", (err) =>
        if config.redis.redis_db_num?
          client.select config.redis.redis_db_num, =>
            callback(null, client)
        else
          callback(null, client)
    client
