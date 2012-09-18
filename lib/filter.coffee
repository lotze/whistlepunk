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
          cb()
          #@processFromHolding message, cb
    ], callback
    
  processValidation: (message, callback) =>
    callback()
    # TODO: check if this message indicates the user is super valid and awesome
    # if message.eventName in validationEventList || message.client in validationClientList
    #   @storeValidation message.timestamp, message.userId
    #   @storeValidation message.timestamp, message.oldGuid if message.oldGuid?
    #   @storeValidation message.timestamp, message.newGuid if message.newGuid?
    # @churnValidation message.timestamp
    # callback()

  storeValidation: (timestamp, guid, callback) =>
    @filter_redis_client.zadd @valid_users_zstore_key, timestamp, guid
    callback()
    
  validationEventList: =>
    ['jsCharacteristics', 'login', 'loginGuidChange']

  validationClientList: =>
    ['iPad app', 'iPhone app']
    
  checkValidation: (message, callback) =>
    callback()
    
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
    
  processFromHolding: (timestamp, callback) =>
    oneHourEarlier = timestamp - 3600
    async.series [
      (cb) =>
        @filter_redis_client.zrangebyscore @holding_zstore_key, 0, oneHourEarlier, (err, results) =>
          cb(err) if err?
          async.forEachSeries results, loggedEventJson, (cb2) =>
            loggedEvent = parseJSON(loggedEventJson)
            @checkValidation loggedEvent, (err2, isValid) =>
              cb2(err2) if err2?
              if isValid
                @emit 'valid', loggedEventJson
                @storeValidation timestamp, loggedEvent.userId, @checkError
              else
                @emit 'invalid', loggedEventJson
              cb2()
          , cb()
      (cb) =>
        @filter_redis_client.zremrangebyscore @holding_zstore_key, 0, oneHourEarlier, (err, results) =>
          cb(err)
    ], callback
    
module.exports = Filter