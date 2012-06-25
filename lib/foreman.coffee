util = require("util")
EventEmitter = require("events").EventEmitter
redis = require("redis")
async = require('async')

config = require("../config")
Redis = require("../lib/redis")
DbLoader = require("../lib/db_loader")
Db = require('mongodb').Db
Server = require('mongodb').Server

glob = require("glob")

fs = require("fs")
FileLineStreamer = require("../lib/file_line_streamer")
UnionRep = require("../lib/union_rep")

class Foreman extends EventEmitter
  constructor: ->
    super()

  init: (callback) =>
    @unionRep = new UnionRep()
    @setMaxListeners(12)
    @redis_key = "distillery:" + process.env.NODE_ENV + ":msg_queue"
    Redis.getClient (err, client) =>
      @local_redis = client
      callback(err, client)

  connect: (callback) =>
    @connectRedis()
    @startProcessing()

  connectRedis: =>
    @redis_client = redis.createClient(config.msg_source_redis.port, config.msg_source_redis.host)
    @redis_client.select config.msg_source_redis.db_num  if config.msg_source_redis.db_num
    console.log "Redis connected."
    @redis_client.once "end", =>
      console.log "Lost connection to Redis. Reconnecting..."
      @connectRedis()

  terminate: ->

  startProcessing: =>
    @redis_client.brpop @redis_key, 0, (err, reply) =>
      if err?
        console.error "Error during Redis BRPOP: " + err
        @startProcessing()
      else
        list = reply[0]
        message = reply[1]
        @handleMessage message

  handleMessage: (jsonString) =>
    try
      @processMessage JSON.parse(jsonString)
    catch err
      console.log "Error processing message:" + jsonString + "; error was " + err
    finally
      @startProcessing()

  processMessage: (message, jsonString=null) =>
    @emit message.eventName, message
    jsonString ||= JSON.stringify(message)
    @local_redis.set "whistlepunk:last_event_processed", jsonString
    console.log message.eventName, message  if process.env.NODE_ENV is "test"
    
  processLine: (jsonString) =>
    @processMessage JSON.parse(jsonString)
    
  clearDatabase: (callback) =>
    async.parallel [
      (setup_cb) =>
        dbloader = new DbLoader()
        setup_cb(null, dbloader.db())
      (setup_cb) =>
        mongo = new Db(config.mongo_db_name, new Server(config.mongo_db_server, config.mongo_db_port, {}), {})
        mongo.open (err, mongo_db) =>
          setup_cb(err, mongo)
      (setup_cb) =>
        Redis.getClient setup_cb
    ], (e, data_stores) =>
      callback(e) if e?
      [db, mongo, local_redis] = data_stores
      async.parallel [
        (parallel_callback) => db.query("TRUNCATE TABLE olap_users").execute parallel_callback
        (parallel_callback) => db.query("TRUNCATE TABLE sources_users").execute parallel_callback
        (parallel_callback) => db.query("TRUNCATE TABLE users_created_at").execute parallel_callback
        (parallel_callback) => db.query("TRUNCATE TABLE users_membership_status_at").execute parallel_callback
        (parallel_callback) => db.query("TRUNCATE TABLE all_measurements").execute parallel_callback
        (parallel_callback) => db.query("TRUNCATE TABLE all_objects").execute parallel_callback
        (parallel_callback) => db.query("TRUNCATE TABLE summarized_metrics").execute parallel_callback
        (parallel_callback) => db.query("TRUNCATE TABLE timeseries").execute parallel_callback
        (parallel_callback) => db.query("TRUNCATE TABLE shares").execute parallel_callback
        (parallel_callback) => db.query("TRUNCATE TABLE in_from_shares").execute parallel_callback
        (parallel_callback) => local_redis.flushdb parallel_callback
        (parallel_callback) => mongo.collection 'compressedActivity', (err, compressedActivity) =>
          compressedActivity.drop (err, results) =>
            if !err? || err.errmsg == 'ns not found'
              parallel_callback()
            else
              parallel_callback(err, results)
        (parallel_callback) => mongo.collection 'compressedBoardActivity', (err, compressedActivity) =>
          compressedActivity.drop (err, results) =>
            if !err? || err.errmsg == 'ns not found'
              parallel_callback()
            else
              parallel_callback(err, results)
       ], (err, results) =>
        callback err, results

  getLogFilesInOrder: (directory, callback) =>
    return callback(null, [ "#{directory}/shares.json", "#{directory}/sessions.json" ]) if process.env.NODE_ENV is "development"

    glob "**/learnist.log.1.*", null, (err, files) =>
      matchedFiles = (file for file in files when file.match(/learnist\.log\.1.*/))
      matchedFiles = matchedFiles.sort (a, b) =>
        a_matches = a.match(/(\d{8})_(\d{6})/)
        b_matches = b.match(/(\d{8})_(\d{6})/)
        a_num = "#{a_matches[1]}#{a_matches[2]}"
        b_num = "#{b_matches[1]}#{b_matches[2]}"
        return(parseInt(a_num) - parseInt(b_num))

      callback err, matchedFiles
      
  addWorker: (name, worker, callback) =>
    @unionRep.addWorker(name, worker)
    worker.init callback
    
  addAllWorkers: (callback) =>
    files = fs.readdirSync(__dirname + '/../workers')
    async.forEach files, (workerFile, worker_callback) =>
      workerName = workerFile.replace('.js', '')
      WorkerClass = require('../workers/'+workerFile)
      @addWorker(workerName, new WorkerClass(this), worker_callback)
    , callback
      
  # for testing/confirming that there are no jobs in progress: either callback immediately or when the unionRep is next drained
  callbackWhenClear: (callback) =>
    if @unionRep.total == 0
      callback()
    else
      @unionRep.once 'drain', =>
        callback()
  
  processFiles: (logPath, eventBounds..., callback) =>
    [firstEvent, lastEvent] = eventBounds
    logPath ||= if process.env.NODE_ENV == 'development' then "/Users/grockit/workspace/whistlepunk/test/log" else "/opt/grockit/log"
    @getLogFilesInOrder logPath, (err, fileList) =>
      return callback(err) if err?
      async.forEachSeries fileList, (fileName, file_cb) =>
        console.log("WhistlePunk: processing file: " + fileName) unless process.env.NODE_ENV == 'test'
        @processFile(fileName, firstEvent, lastEvent, file_cb)
      , (err) =>
        callback(err)    

  processFile: (file, eventBounds..., callback) =>
    [firstEvent, lastEvent] = eventBounds
    reader = new FileLineStreamer(file)
    @unionRep.on 'saturate', =>
      reader.pause()
    @unionRep.on 'drain', =>
      reader.resume()
    reader.on 'data', (line) =>
      try
        matches = line.toString().match(/^[^\{]*(\{.*\})/)
        if (matches?) and (matches.length > 0)
          jsonString = matches[1]
          streamData = JSON.parse(jsonString)
          if (!lastEvent? || streamData.timestamp <= lastEvent.timestamp) && (!firstEvent? || streamData.timestamp > firstEvent.timestamp)
            @processMessage(streamData, jsonString)
        else
          console.trace "event line " + line + " did not match as expected"
      catch error
        console.trace "event line " + line + " had a serious parsing issue: #{error}"
    reader.on 'end', ->
      callback() if callback?
    reader.start()    

module.exports = Foreman