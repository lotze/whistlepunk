redis = require('redis')
config = require('../config')

client = null

module.exports =
  getClient: (callback) =>
    if client?
      callback(null, client) if callback?
    else
      temp_client = redis.createClient(config.redis.port, config.redis.host)
      temp_client.on "error", (err) ->
        console.log("Error " + err);
      temp_client.once "ready", (err) =>
        if config.redis.db_num?
          temp_client.select config.redis.db_num, =>
            client = temp_client
            callback(null, client) if callback?
        else
          client = temp_client
          callback(null, client) if callback?
