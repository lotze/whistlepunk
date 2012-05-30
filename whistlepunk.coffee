#!/usr/bin/env coffee

process.env.NODE_ENV ?= 'development'

require('coffee-script')
redis = require('redis')
Redis = require("./lib/redis")
config = require('./config')
FileProcessorHelper = require('./lib/file_processor_helper')
UnionRep = require('./lib/union_rep')

fs = require('fs')
async = require('async')
foreman = require('./lib/foreman.js')

process.on 'uncaughtException', (e) ->
  console.error("UNCAUGHT EXCEPTION: ", e, e.stack)

quit = ->
  process.exit(0)

process.on('SIGINT', quit)
process.on('SIGKILL', quit)

class Application
  constructor: (@foreman) ->
    @client = Redis.getClient()

  terminate: =>
    @foreman.terminate()

  run: =>
    @unionRep = new UnionRep()

    @foreman.init (err) =>
      files = fs.readdirSync('./workers')
      async.forEach files, (workerFile, worker_callback) =>
        workerName = workerFile.replace('.js', '')
        WorkerClass = require('./workers/'+workerFile)
        worker = new WorkerClass(@foreman)
        worker.init(worker_callback)
        @unionRep.addWorker(workerName, worker)
      , (err) =>
        throw err if err?
        @startProcessing()

  startProcessing: =>
    console.log "Starting processing"
    if process.env.REPROCESS?
      @reprocess()
    else
      @processNormally()

  processNormally: =>
    console.log "Processing normally"
    console.log "WhistlePunk: connecting foreman to remote redis"
    @foreman.connect (err) =>
      throw err if err?
      console.log 'WhistlePunk: running...'

  reprocess: =>
    console.log "Reprocessing"
    @fileProcessorHelper = new FileProcessorHelper(@unionRep)

    async.parallel [
      (cb) => @client.get 'whistlepunk:last_event_processed', cb
      (cb) => @client.get 'whistlepunk:last_event_to_process', cb
    ], (err, results) =>
      return throw err if err?
      [from, to] = results
      if from?
        @resumeReprocessing(from, to)
      else
        @startReprocessing()

  resumeReprocessing: (from, to) =>
    @reprocessFromTo from, to, (err, results) =>
      @client.del 'whistlepunk:last_event_processed', (err, results) =>
        @processNormally()

  startReprocessing: =>
    async.series [
      (cb) =>
        # first delete all data
        console.log "WhistlePunk: deleting old data"
        @fileProcessorHelper.clearDatabase(cb)
      (cb) =>
        # then get the first event in the redis queue
        console.log "WhistlePunk: getting first redis event"
        redis_key = "distillery:" + process.env.NODE_ENV + ":msg_queue"
        remote_redis_client = redis.createClient(config.msg_source_redis.port, config.msg_source_redis.host);
        if config.msg_source_redis.redis_db_num?
          remote_redis_client.select(config.msg_source_redis.redis_db_num);
        remote_redis_client.brpop redis_key, 0, (err, reply) =>
          if err?
            console.error "Error during Redis BRPOP"
            return throw err
          else
            console.log("Got it -- will reprocess up to ", reply)
            jsonString = reply[1]
            @client.set 'whistlepunk:last_event_to_process', jsonString, (err, result) =>
              console.log("error updating last event to process: ",err,err.stack) if err?
              @reprocessFromTo(null, jsonString, cb)
    ], (err, results) =>
      throw err if err?
      @client.del 'whistlepunk:last_event_processed', (err, results) =>
        @processNormally()

  reprocessFromTo: (from, to, cb) =>
    # then process all data from all log files up to that event
    @firstMessage = JSON.parse(from) if from?
    @finalMessage = JSON.parse(to) if to?
    logPath = if process.env.NODE_ENV == 'development' then "/Users/grockit/workspace/whistlepunk/test/log" else "/opt/grockit/log"
    @fileProcessorHelper.getLogFilesInOrder logPath, (err, fileList) =>
      if err?
        console.error("Error while getting log files")
        throw err
      else
        console.log "Processing log file list: ", fileList
        async.forEachSeries fileList, @reprocessFile, (err) =>
          console.log("!!! DONE with async.forEachSeries")
          cb()

  reprocessFile: (fileName, file_cb) =>
    console.log("WhistlePunk: processing old log: " + fileName)
    try
      "whistlepunk:#{process.env.NODE_ENV}:finalMessage"
      @fileProcessorHelper.processFileForForeman(fileName, @foreman, @firstMessage, @finalMessage, file_cb)
    catch err
      console.error("Uncaught error processing file for foreman: ",err,err.stack)
      file_cb()

app = new Application(foreman)


process.on 'SIGKILL', ->
  app.terminate()

process.on 'SIGINT', ->
  app.terminate()

exports =
  run: app.run
  terminate: app.terminate

app.run()
