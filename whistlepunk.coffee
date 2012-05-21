#!/usr/bin/env coffee

process.env.NODE_ENV ?= 'development'

require('coffee-script')
redis = require('redis')
config = require('./config')
FileProcessorHelper = require('./lib/file_processor_helper')

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

  terminate: =>
    @foreman.terminate()

  run: =>
    workers = {}

    @foreman.init (err) =>
      files = fs.readdirSync('./workers')
      async.forEach files, (workerFile, worker_callback) =>
        workerName = workerFile.replace('.js', '')
        WorkerClass = require('./workers/'+workerFile)
        workers[workerName] = new WorkerClass(foreman)
        workers[workerName].init(worker_callback)  
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
    @fileProcessorHelper = new FileProcessorHelper()
    async.series [
      (cb) =>
        # first delete all data
        console.log "WhistlePunk: deleting old data"
        @fileProcessorHelper.clearDatabase(cb)
      (cb) =>
        # then get the first event in the redis queue
        console.log "WhistlePunk: getting first redis event"
        redis_client = redis.createClient(config.msg_source_redis.port, config.msg_source_redis.host)
        redis_key = "distillery:" + process.env.NODE_ENV + ":msg_queue"
        redis_client.brpop redis_key, 0, (err, reply) =>
          @reprocessUpTo(err, reply, cb)
    ], (err, results) =>
      throw err if err?
      @processNormally()
            
  reprocessUpTo: (err, reply, cb) =>
    if err?
      console.error "Error during Redis BRPOP"
      throw err

    [list, message] = reply
    console.log "got list " + list + ", msg " + message
    # then process all data from all log files up to that event
    @finalMessage = JSON.parse(message)
    logPath = if process.env.NODE_ENV == 'development' then "/Users/grockit/workspace/metricizer/spec/log" else "/opt/grockit/log"
    @fileProcessorHelper.getLogFilesInOrder logPath, (err, fileList) =>
      if err?
        console.error("Error while getting log files")
        throw err

      console.log "Processing log file list: ", fileList
      async.forEachSeries fileList, @reprocessFile, (err) =>
        console.log("!!! DONE with async.forEachSeries")
        cb()

  reprocessFile: (fileName, file_cb) =>
    console.trace("WTF!?") unless fileName?
    console.log("WhistlePunk: processing old log: " + fileName)
    try
      @fileProcessorHelper.processFileForForeman(fileName, @foreman, @finalMessage, file_cb)
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
