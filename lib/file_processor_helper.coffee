async = require("async")
EventEmitter = require("events").EventEmitter
util = require("util")
FileLineReader = require("../lib/file_line_reader").FileLineReader
fs = require("fs")

class FileProcessorHelper extends EventEmitter
  constructor: ->
    @jsonFinderRegEx = new RegExp(/^[^\{]*(\{.*\})/)
    DbLoader = require("../lib/db_loader.js")
    dbloader = new DbLoader()
    @db = dbloader.db()

  processLine: (line) =>
    json_data = JSON.parse(line)
    @emit json_data.eventName, json_data

  getLogFilesInOrder: (directory, callback) =>
    return callback(null, [ "shares.log", "sessions.log" ])  if process.env.NODE_ENV is "development"
    fs.readdir directory, (err, files) ->
      matchedFiles = (file for file in files when file.match(/^learnist\.log\.1.*/))
      matchedFiles = matchedFiles.sort()
      matchedFiles.unshift "learnist.log.old"
      matchedFiles.push "learnist.log"
      callback err, matchedFiles

  processFile: (file) =>
    lazy = require("lazy")
    fs = require("fs")
    self = this
    new lazy(fs.createReadStream(file)).lines.forEach (line) ->
      matches = line.toString().match(/^[^\{]*(\{.*\})/)
      jsonString = matches[1]
      streamData = JSON.parse(jsonString)
      self.emit streamData.eventName, streamData

  processFileForForeman: (file, foreman, lastEvent, callback) =>
    fs = require("fs")
    self = this
    reader = new FileLineReader(file)
    loop
      line = reader.nextLine()
      matches = line.toString().match(/^[^\{]*(\{.*\})/)
      if (matches?) and (matches.length > 0)
        jsonString = matches[1]
        streamData = JSON.parse(jsonString)
        foreman.emit streamData.eventName, streamData  if streamData.timestamp <= lastEvent.timestamp
      else
        console.log "event line " + jsonString + " had a parsing issue -- SKIPPING"
      break unless reader.hasNextLine()
    callback null

  clearDatabase: (callback) =>
    async.parallel [ (parallel_callback) ->
      @db.query("TRUNCATE TABLE olap_users").execute parallel_callback
    , (parallel_callback) ->
      @db.query("TRUNCATE TABLE sources_users").execute parallel_callback
    , (parallel_callback) ->
      @db.query("TRUNCATE TABLE users_created_at").execute parallel_callback
    , (parallel_callback) ->
      @db.query("TRUNCATE TABLE users_membership_status_at").execute parallel_callback
    , (parallel_callback) ->
      @db.query("TRUNCATE TABLE all_measurements").execute parallel_callback
    , (parallel_callback) ->
      @db.query("TRUNCATE TABLE all_objects").execute parallel_callback
    , (parallel_callback) ->
      @db.query("TRUNCATE TABLE summarized_metrics").execute parallel_callback
    , (parallel_callback) ->
      @db.query("TRUNCATE TABLE timeseries").execute parallel_callback
    , (parallel_callback) ->
      @db.query("TRUNCATE TABLE shares").execute parallel_callback
    , (parallel_callback) ->
      @db.query("TRUNCATE TABLE in_from_shares").execute parallel_callback
     ], (err, results) ->
      callback err, results


module.exports = FileProcessorHelper