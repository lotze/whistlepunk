redis = require('redis')
config = require('../config')

client = null

module.exports =
  getClient: (callback) =>
    if client?
      callback(null, client) if callback?
    else
      client = redis.createClient(config.redis.port, config.redis.host)
      client.on "error", (err) ->
        console.log("Error " + err);
      client.once "ready", (err) =>
        if config.redis.db_num?
          client.select config.redis.db_num, =>
            callback(null, client) if callback?
        else
          callback(null, client) if callback?
    return client
