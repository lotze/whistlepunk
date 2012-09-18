#!/usr/bin/env coffee
config = require("../config")
redisBuilder = require('../lib/redis_builder')
process.env.NODE_ENV ?= 'development'

require('coffee-script')
Filter = require('./filter')

process.on 'uncaughtException', (e) ->
  console.error("UNCAUGHT EXCEPTION: ", e, e.stack)

quit = ->
  process.exit(0)

process.on('SIGINT', quit)
process.on('SIGKILL', quit)

class Application
  constructor: (@filter) ->
    # TODO: set up watching filter's output events
    console.log("Creating application")

  init: (callback) =>
    @distillery_redis_key = "distillery:" + process.env.NODE_ENV + ":msg_queue"
    @connectRedis(callback)
    
  connectRedis: (callback) =>
    redisBuilder process.env.NODE_ENV, 'distillery', (err, client) =>
      @distillery_redis_client = client
      callback()
      
  terminate: ->
    quit()
    
  processMessage: (jsonString) =>
    console.log("I am totally processing #{jsonString}")
    # TODO: actually build filter ;)
    # @filter.processMessage JSON.parse(jsonString), jsonString    
    
  startProcessing: =>
    console.log("I am for reals processing from #{@distillery_redis_client}")
    @distillery_redis_client.brpop @distillery_redis_key, 0, (err, reply) =>
      console.log("I got a thing!")
      if err?
        console.error "Error during Redis BRPOP: " + err
        @startProcessing()
      else
        jsonString = reply[1]
        try
          @processMessage(jsonString)
        catch err
          console.log "Error processing message:" + jsonString + "; error was " + err
        finally
          @startProcessing()
        
  run: =>
    @startProcessing()
    
app = new Application(new Filter())

process.on 'SIGKILL', ->
  app.terminate()

process.on 'SIGINT', ->
  app.terminate()

module.exports = app


# NOTES ON SETUP
# Datastores:
#
# Incoming Redis: Distillery Redis
# - Managed by preprocessor
# Outgoing Redis: Whistlepunk Redis
# - Managed by preprocessor
#
# Internal Redis: Holding Queue
# - Managed by Filter instance
# Internal Redis: Validated Users
# - Managed by Filter instance
#
#
# 1) Dispatcher: Pulls stuff from Distillery Redis
# - Stores all logs in holding redis queue (ordered set, sorted on log timestamp)
# - Sends all logs to validation process
# - Sends all log timestamps to holding processor
# 
# 2) Validator: gets logs from Dispatcher
# - Checks individual logs to determine if userId is "valid"
# - Based on iOS, login, jsCharacteristics, etc.
# - Stores valid userId's with timestamp of last "valid" event
#
# 3) Holding Processor: 
# - Gets current log from Dispatcher
# - Processes current log to find timestamp
# - Fetches all logs from the Dispatcher holding redis queue with timestamps less than one hour prior to the current log's timestamp
# - Iterates through fetched logs and determines if the log is sent to "pass" or "fail" based on whether or not the log's userId
#
# 4) Pass Handler:
# - Expire and churn valid userId's based on timestamps older than 24 hours prior to current log timestamp
# - Updates latest valid timestamp for guid in Validator's redis store based on timestamp for "passed" logs.
# - Writes "passed" log data to valid logs file
# - Sends log to output redis queue for processing by whistlepunk
# 
# 5) Fail Handler: 
# - Write "failed" log to failed logs file
#
#





