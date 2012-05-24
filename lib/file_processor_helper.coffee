async = require("async")
EventEmitter = require("events").EventEmitter
util = require("util")
FileLineStreamer = require("../lib/file_line_streamer")
fs = require("fs")
Redis = require("../lib/redis")
config = require("../config")

class FileProcessorHelper extends EventEmitter
  constructor: (@unionRep) ->
    @jsonFinderRegEx = new RegExp(/^[^\{]*(\{.*\})/)
    DbLoader = require("../lib/db_loader.js")
    dbloader = new DbLoader()
    @db = dbloader.db()
    Redis.getClient (err, client) =>
      @client = client

  processLine: (line) =>
    json_data = JSON.parse(line)
    @processMessage(json_data)
    
  processMessage: (json_data) =>
    @emit json_data.eventName, json_data

  getLogFilesInOrder: (directory, callback) =>
    return callback(null, [ "#{directory}/shares.log", "#{directory}/sessions.log" ]) if process.env.NODE_ENV is "development"
    fs.readdir directory, (err, files) ->
      matchedFiles = (file for file in files when file.match(/^learnist\.log\.1.*/))
      matchedFiles = matchedFiles.sort (a, b) =>
        a_matches = a.match(/(\d{8})_(\d{6})/)
        b_matches = b.match(/(\d{8})_(\d{6})/)
        a_num = "#{a_matches[1]}#{a_matches[2]}"
        b_num = "#{b_matches[1]}#{b_matches[2]}"
        return(parseInt(a_num) - parseInt(b_num))
      matchedFiles.unshift "learnist.log.old"
      matchedFiles.push "learnist.log"

      matchedFiles = ("#{directory}/#{file}" for file in matchedFiles)
      callback err, matchedFiles

  processFile: (file, callback) =>
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
          @processMessage(streamData)
        else
          console.trace "event line " + line + " did not match as expected"
      catch error
        console.trace "event line " + line + " had a serious parsing issue: #{error}"
    reader.on 'end', ->
      callback null if callback?
    reader.start()

  processFileForForeman: (file, foreman, firstEvent, lastEvent, callback) =>
    reader = new FileLineStreamer(file)

    @unionRep.on 'saturate', =>
      console.log "Union workers working too hard, taking a mandatory break..."
      reader.pause()
    @unionRep.on 'drain', =>
      console.log "BACK TO WORK YOU LAZY BUMS"
      reader.resume()

    reader.on 'data', (line) ->
      try
        matches = line.toString().match(/^[^\{]*(\{.*\})/)
        if (matches?) and (matches.length > 0)
          jsonString = matches[1]
          streamData = JSON.parse(jsonString)
          if (!lastEvent? || streamData.timestamp <= lastEvent.timestamp) && (!firstEvent? || streamData.timestamp > firstEvent.timestamp)
            foreman.processMessage(streamData)
            @client.set 'whistlepunk:last_event_processed', jsonString, (err, result) =>
              console.log("error updating last event processed: ",err,err.stack) if err?
        else
          console.trace "event line " + line + " did not match as expected"
      catch error
        console.trace "event line " + line + " had a serious parsing issue: #{error}"
    reader.on 'end', ->
      callback null
    reader.start()

  clearDatabase: (callback) =>
    async.parallel [ 
      (parallel_callback) => @db.query("TRUNCATE TABLE olap_users").execute parallel_callback
      (parallel_callback) => @db.query("TRUNCATE TABLE sources_users").execute parallel_callback
      (parallel_callback) => @db.query("TRUNCATE TABLE users_created_at").execute parallel_callback
      (parallel_callback) => @db.query("TRUNCATE TABLE users_membership_status_at").execute parallel_callback
      (parallel_callback) => @db.query("TRUNCATE TABLE all_measurements").execute parallel_callback
      (parallel_callback) => @db.query("TRUNCATE TABLE all_objects").execute parallel_callback
      (parallel_callback) => @db.query("TRUNCATE TABLE summarized_metrics").execute parallel_callback
      (parallel_callback) => @db.query("TRUNCATE TABLE timeseries").execute parallel_callback
      (parallel_callback) => @db.query("TRUNCATE TABLE shares").execute parallel_callback
      (parallel_callback) => @db.query("TRUNCATE TABLE in_from_shares").execute parallel_callback
      (parallel_callback) => @client.smembers 'sessionizer:is_first', (err, results) =>
        @client.srem 'sessionizer:is_first', results..., parallel_callback
      (parallel_callback) => @client.hkeys 'sessionizer:start_time', (err, results) =>
        @client.hdel 'sessionizer:start_time', results..., parallel_callback
      (parallel_callback) => @client.hkeys 'sessionizer:activity_id', (err, results) =>
        @client.hdel 'sessionizer:activity_id', results..., parallel_callback
      (parallel_callback) => @client.zremrangebyscore 'sessionizer:end_time', -1, 99999999999999999, parallel_callback
      (parallel_callback) => @client.hkeys 'sessionizer:next_day_start', (err, results) =>
        @client.hdel 'sessionizer:next_day_start', results..., parallel_callback
      (parallel_callback) => @client.zremrangebyscore 'sessionizer:next_day_end', -1, 99999999999999999, parallel_callback
     ], (err, results) =>
      callback err, results

module.exports = FileProcessorHelper