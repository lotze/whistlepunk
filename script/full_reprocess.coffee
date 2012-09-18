#!/usr/bin/env coffee

process.env.NODE_ENV ?= 'development'

require('coffee-script')

Foreman = require('../lib/foreman')

config = require('../config')
Redis = require("../lib/redis")
redis = require('redis')

child_process = require('child_process')
fs = require('fs')
util = require('util')
async = require('async')

# stop whistlepunk
# run sorting script to make sure we have copies of all logs up to the present moment
# check the local redis to see if we are in the middle of a reprocess
# get the next event to be processed from the msg queue
# clear out database
# for continuing a halted reprocess: get the start event -- the last processed event in redis
# process from the logs, between (the last processed event from the dump, the next event to be processed from the msg queue]  
#  -- do not process the last event from the dump (it's already been processed), but do process the event you pulled off the msg queue (you just pulled it off, so it won't be there for whistlepunk to process)
# start whistlepunk

class Application
  constructor: ->
    console.log("doing (or continuing) a full reprocess:")
    @last_event_processed = null
    @last_event_to_process = null
    @whistlepunk_running = false
    @local_redis_client = null
    @foreman = null

  startReprocessing: (callback) =>
    async.series [
      (cb) =>
        # run downloading/sorting script to get logs up to date on S3
        if (process.env.NODE_ENV == 'production' || process.env.NODE_ENV == 'staging')
          console.log("forcing an update to S3 and getting latest logs from the app...")
          child_process.exec "ssh 174.129.119.21 'RAILS_ENV=#{process.env.NODE_ENV} ROTATE_LOGS=TRUE /bin/bash /home/grockit/metricizer/script/update_stored_logs.sh'", cb
        else
          cb()
      (cb) =>
        # after having run downloading/sorting script to get logs up to date on S3, download into local directory
        if (process.env.NODE_ENV == 'production' || process.env.NODE_ENV == 'staging')
          console.log("syncing latest logs from S3...")
          child_process.exec "s3cmd sync s3://com.grockit.distillery/learnist/#{process.env.NODE_ENV}/sorted/ #{config.backup.full_log_dir}/", cb
        else
          cb()
      (cb) =>
        # get the next event to be processed from the msg queue
        if (process.env.NODE_ENV == 'production' || process.env.NODE_ENV == 'staging')
          redis_key = "distillery:" + process.env.NODE_ENV + ":msg_queue"
          remote_redis_client = redis.createClient(config.filtered_redis.port, config.filtered_redis.host)
          if config.filtered_redis.db_num?
            remote_redis_client.select(config.filtered_redis.db_num)
          remote_redis_client.brpop redis_key, 0, (err, reply) =>
            return cb(err) if err?
            console.log("Got next event -- will reprocess up to ", reply)
            jsonString = reply[1]
            @last_event_to_process = JSON.parse(jsonString)
            @local_redis_client.set 'whistlepunk:last_event_to_process', jsonString, cb
        else
          @last_event_to_process = {timestamp:999999999999999999}
          cb()
      (cb) =>
        # process from the logs, between (the last processed event from the dump, the next event to be processed from the msg queue]  
        console.log("Time to begin reprocessing from the very beginning, up to #{@last_event_to_process.timestamp}.")
        @foreman = new Foreman()
        @foreman.init (err) =>
          return cb(err) if err?
          @foreman.clearDatabase (db_err, db_result) =>
            return cb(db_err) if db_err?
            @foreman.addAllWorkers (err) =>
              return cb(err) if err?
              @foreman.processFiles(config.backup.full_log_dir, @last_event_processed, @last_event_to_process, cb)
    ], callback  

  resumeReprocessing: (from, to, callback) =>
    @last_event_processed = JSON.parse(from)
    @last_event_to_process = JSON.parse(to)
    # process from the logs, between (the last processed event from the dump, the next event to be processed from the msg queue]  
    console.log("Time to resume reprocess, after #{@last_event_processed.timestamp} and up to #{@last_event_to_process.timestamp}.")
    @foreman = new Foreman()
    @foreman.init (err) =>
      callback(err) if err?
      @foreman.addAllWorkers (err) =>
        return callback(err) if err?
        @foreman.processFiles(config.backup.full_log_dir, @last_event_processed, @last_event_to_process, callback)


  run: =>
    async.series [
      (cb) =>
        if (process.env.NODE_ENV == 'production' || process.env.NODE_ENV == 'staging')
          child_process.exec "sudo status whistlepunk_#{process.env.NODE_ENV}", (err, result) =>
            cb(err) if err?
            @whistlepunk_running = (result.match(/whistlepunk_production start\/running/))?
            if !@whistlepunk_running
              console.log "Whistlepunk is not currently running; will not attempt to stop or restart it at the end."
            cb()
        else
          cb()
      (cb) =>
        # stop whistlepunk
        if (process.env.NODE_ENV == 'production' || process.env.NODE_ENV == 'staging') && @whistlepunk_running
          console.log("stopping whistlepunk...")
          child_process.exec "sudo stop whistlepunk_#{process.env.NODE_ENV}", cb
        else
          cb()
      (cb) =>
        # get redis client
        console.log("getting redis client...")
        Redis.getClient (err, client) =>
          return cb(err) if err?
          @local_redis_client = client
          cb()
      (cb) =>
        # load data -- check for reprocess by looking at whistlepunk:
        async.parallel [
          (pcp) => @local_redis_client.get 'whistlepunk:last_event_processed', pcp
          (pcp) => @local_redis_client.get 'whistlepunk:last_event_to_process', pcp
        ], (err, results) =>
          return throw err if err?
          [from, to] = results
          if to? && from?
            @resumeReprocessing(from, to, cb)
          else
            @startReprocessing(cb)
      (cb) =>
        console.log("finished reprocessing!  ready to restart whistlepunk!")
        @local_redis_client.del 'whistlepunk:last_event_to_process', cb
      (cb) =>
        if (process.env.NODE_ENV == 'production' || process.env.NODE_ENV == 'staging') && @whistlepunk_running
          console.log("starting whistlepunk...")
          child_process.exec "sudo start whistlepunk_#{process.env.NODE_ENV}", cb
        else
          cb()
    ], (err, results) =>
      if err?
        console.log("Error was #{err}, results were #{results}")
        process.exit(-1)
      process.exit(0)

app = new Application()

process.on 'SIGKILL', ->
  process.exit(0)

process.on 'SIGINT', ->
  process.exit(0)
  
process.on 'uncaughtException', (e) ->
  console.error("UNCAUGHT EXCEPTION: ", e, e.stack)  
  process.exit(0)

app.run()