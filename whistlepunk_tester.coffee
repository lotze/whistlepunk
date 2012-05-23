#!/usr/bin/env coffee

process.env.NODE_ENV ?= 'development'

require('coffee-script')
redis = require('redis')
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

  terminate: =>
    @foreman.terminate()

  run: (file) =>
    @unionRep = new UnionRep()
    @fileProcessorHelper = new FileProcessorHelper(@unionRep)

    @foreman.init (err) =>
      files = fs.readdirSync(__dirname + '/workers')
      async.forEach files, (workerFile, worker_callback) =>
        workerName = workerFile.replace('.js', '')
        WorkerClass = require('./workers/'+workerFile)
        worker = new WorkerClass(foreman)
        worker.init(worker_callback)
        @unionRep.addWorker(workerName, worker)
      , (err) =>
        throw err if err?
        @processFile file, =>
          process.exit(0)
    
  processFile: (fileName, file_cb) =>
    console.trace("WTF!?") unless fileName?
    console.log("WhistlePunk: processing old log: " + fileName)
    try
      @fileProcessorHelper.processFileForForeman(fileName, @foreman, {timestamp: 99999999999999999}, file_cb)
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

app.run(process.argv[2])
