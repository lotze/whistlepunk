redisBuilder = require('../lib/redis_builder')

util = require("util")
EventEmitter = require("events").EventEmitter
async = require('async')

fs = require("fs")

#
# Filter is made up of:
# Dispatcher
# Validator
# Backlog Processor
# Pass Handler
# Fail Handler
#

class Filter extends EventEmitter
  constructor: ->
    super()

  init: (callback) =>
    @holding_zstore_key = "filter:" + process.env.NODE_ENV + ":holding_zstore"
    @valid_users_zstore_key = "filter:" + process.env.NODE_ENV + ":valid_users"
    @validationEventList = ['jsCharacteristics', 'login', 'loginGuidChange']
    @validationClientList = ['iPad app', 'iPhone app']
    @connectRedis(callback)
    
  connectRedis: (callback) =>
    async.parallel [
      async.apply redisBuilder, process.env.NODE_ENV, 'distillery'
      async.apply redisBuilder, process.env.NODE_ENV, 'internal'
    ], (err, results) =>
      [@distillery_redis_client, @filter_redis_client] = results
      callback(err)

  dispatchMessage: (jsonString, callback = ->) =>
    console.log message.eventName, message if process.env.NODE_ENV is "development"
    message = JSON.parse(jsonString)
    async.parallel [
      (cb) => @pushToHolding message.timestamp, jsonString, cb
      (cb) => @processValidation message, (err) =>
        @processOldEventsFromHolding message.timestamp, cb
    ], callback
    
  processValidation: (message, callback) =>
    # check if this message indicates the user is super valid and awesome
    async.parallel [
      (cb0) =>
        if message.eventName in @validationEventList || message.client in @validationClientList
          async.parallel [
            (cb) => @storeValidation message.timestamp, message.userId, cb
            (cb) =>
              if message.oldGuid?
                @storeValidation message.timestamp, message.oldGuid, cb
              else
                cb()
            (cb) =>
              if message.newGuid?
                @storeValidation message.timestamp, message.newGuid, cb
              else
                cb()
          ], cb0
        else
          cb0()
      (cb0) => @churnValidation message.timestamp, cb0
    ], callback

  storeValidation: (timestamp, guid, callback) =>
    @filter_redis_client.zadd @valid_users_zstore_key, timestamp, guid
    callback()
    
  checkValidation: (userId, callback) =>
    @filter_redis_client.zscore @valid_users_zstore_key, userId, (err, score) =>
      # console.log("Checked #{userId} and got #{err}/#{score}")
      callback(null, score != null)
    
  churnValidation: (timestamp, callback) =>
    callback()
    
  updateHolding: (message, jsonString, callback) =>
    @pushToHolding message.timestamp, jsonString
    @processFromHolding message.timestamp
    callback()
    
  pushToHolding: (timestamp, jsonString, callback = ->) =>
    @filter_redis_client.zadd @holding_zstore_key, timestamp, jsonString, callback

  checkError: (err, results) =>
    console.log("Error: #{err}") if err?

  processOneEventFromHolding: (logEventJson, callback) =>
    loggedEvent = JSON.parse(logEventJson)
    @checkValidation loggedEvent.userId, (err, isValid) =>
      return callback(err) if err?
      if isValid
        @emit 'valid', logEventJson
        @storeValidation loggedEvent.timestamp, loggedEvent.userId, @checkError
      else
        @emit 'invalid', logEventJson
      callback()

  processOldEventsFromHolding: (timestamp, callback) =>
    oneHourEarlier = timestamp - 3600
    async.series [
      (cb) =>
        @filter_redis_client.zrangebyscore @holding_zstore_key, 0, oneHourEarlier, (err, results) =>
          return cb(err) if err?
          async.forEachSeries results, @processOneEventFromHolding, cb
      (cb) =>
        @filter_redis_client.zremrangebyscore @holding_zstore_key, 0, oneHourEarlier, (err, results) =>
          cb(err)
    ], callback

module.exports = Filter