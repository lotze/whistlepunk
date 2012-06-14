#!/usr/bin/env coffee

process.env.NODE_ENV ?= 'development'

require('coffee-script')

Foreman = require('../lib/foreman')

config = require('../config')
Redis = require("../lib/redis")
redis = null

child_process = require('child_process')
fs = require('fs')
util = require('util')
async = require('async')

# stop whistlepunk
# run sorting script to make sure we have copies of all logs up to the present moment
# get the start event -- the last processed event from the dump
# load data from the dump
# - load SQL
# - load redis
# - load mongo
# get the next event to be processed from the msg queue
# process from the logs, between (the last processed event from the dump, the next event to be processed from the msg queue]  
#  -- do not process the last event from the dump (it's already been processed), but do process the event you pulled off the msg queue (you just pulled it off, so it won't be there for whistlepunk to process)
# start whistlepunk

last_event_processed = null
last_event_to_process = null

# get timestamp for backup to use; should be in the format "YYYY-MM-DD"
timestamp = process.argv[2]

console.log("reloading from #{config.backup.dir}/#{timestamp}:")

process.on 'SIGKILL', ->
  process.exit(0)

process.on 'SIGINT', ->
  process.exit(0)
  
process.on 'uncaughtException', (e) ->
  console.error("UNCAUGHT EXCEPTION: ", e, e.stack)  

whistlepunk_running = false

async.series [
  (cb) =>
    if (process.env.NODE_ENV == 'production' || process.env.NODE_ENV == 'staging')
      child_process.exec "sudo status whistlepunk_#{process.env.NODE_ENV}", (err, result) =>
        cb(err) if err?
        whistlepunk_running = (result.match(/whistlepunk_production start\/running/))?
        cb()
    else
      cb()
  (cb) =>
    # stop whistlepunk
    if (process.env.NODE_ENV == 'production' || process.env.NODE_ENV == 'staging') && whistlepunk_running
      console.log("stopping whistlepunk...")
      child_process.exec "sudo stop whistlepunk_#{process.env.NODE_ENV}", cb
    else
      cb()
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
      child_process.exec "s3cmd --no-delete-removed --rexclude='^[^201]' sync s3://com.grockit.distillery/learnist/#{process.env.NODE_ENV}/sorted/ #{config.backup.full_log_dir}/", cb
    else
      cb()
  (cb) =>
    # after downloaded into local directory, move them to the top level of that directory
    if (process.env.NODE_ENV == 'production' || process.env.NODE_ENV == 'staging')
      console.log("centralizing local logs from S3...")
      child_process.exec "find #{config.backup.full_log_dir}/ -type f -exec mv {} #{config.backup.full_log_dir}/ \\;", cb
    else
      cb()
  (cb) =>
    # get redis client
    console.log("getting redis client...")
    Redis.getClient (err, client) =>
      return cb(err) if err?
      redis = client
      cb()
  (cb) =>
    # load data
    async.parallel [
      (load_cb) =>
        # load SQL
        console.log("loading mysql...")
        child_process.exec "mysql -u#{config.db.user} -p#{config.db.password} -h#{config.db.hostname} #{config.db.database} < #{config.backup.dir}/#{timestamp}/mysql.sql", load_cb
      (load_cb) =>
        async.series [
          # shut down redis, copy file, restart redis
          (redis_cb) =>
            console.log("stopping redis...")
            if (process.env.NODE_ENV == 'development')
              child_process.exec "launchctl unload -w ~/Library/LaunchAgents/homebrew.mxcl.redis.plist", redis_cb
            else
              child_process.exec "sudo service redis-server stop", redis_cb
          (redis_cb) =>
            console.log("copying redis backup...")
            # copy redis dump file from backup dir
            input_stream = fs.createReadStream("#{config.backup.dir}/#{timestamp}/redis.rdb")
            output_stream = fs.createWriteStream("#{config.backup.redis_rdb_dir}/dump.rdb")
            util.pump input_stream, output_stream, redis_cb
          (redis_cb) =>
            console.log("starting redis...")
            if (process.env.NODE_ENV == 'development')
              child_process.exec "launchctl load -w ~/Library/LaunchAgents/homebrew.mxcl.redis.plist", redis_cb
            else
              child_process.exec "sudo service redis-server start", redis_cb
        ], load_cb
      (load_cb) =>
        # load mongo
        console.log("loading mongodb...")
        child_process.exec "mongorestore --host #{config.mongo_db_server} --port #{config.mongo_db_port} --db #{config.mongo_db_name} --drop #{config.backup.dir}/#{timestamp}/mongo/#{config.mongo_db_name}", load_cb
    ], cb
  (cb) =>
    # get the next event to be processed from the msg queue
    if (process.env.NODE_ENV == 'production' || process.env.NODE_ENV == 'staging')
      redis_key = "distillery:" + process.env.NODE_ENV + ":msg_queue"
      remote_redis_client = redis.createClient(config.msg_source_redis.port, config.msg_source_redis.host)
      if config.msg_source_redis.redis_db_num?
        remote_redis_client.select(config.msg_source_redis.redis_db_num)
      remote_redis_client.brpop redis_key, 0, (err, reply) =>
        return cb(err) if err?
        console.log("Got next event -- will reprocess up to ", reply)
        jsonString = reply[1]
        last_event_to_process = JSON.parse(jsonString)
        redis.set 'whistlepunk:last_event_to_process', jsonString, cb
    else
      last_event_to_process = {timestamp:999999999999999999}
      cb()
  (cb) =>
    # get the last event processed
    redis.get 'whistlepunk:last_event_processed', (err, last_event) =>
      return cb(err) if err?
      last_event_processed = JSON.parse(last_event)
      cb()
  (cb) =>
    # process from the logs, between (the last processed event from the dump, the next event to be processed from the msg queue]  
    console.log("Time to reprocess, after #{last_event_processed.timestamp} and up to #{last_event_to_process.timestamp}.")
    foreman = new Foreman()
    foreman.init (err) =>
      cb(err) if err?
      foreman.processFiles(config.backup.full_log_dir, last_event_processed, last_event_to_process, cb)
  (cb) =>
    if (process.env.NODE_ENV == 'production' || process.env.NODE_ENV == 'staging') && whistlepunk_running
      console.log("starting whistlepunk...")
      child_process.exec "sudo start whistlepunk_#{process.env.NODE_ENV}", cb
    else
      cb()
], (err, results) =>
  if err?
    console.log("Error was #{err}, results were #{results}")
    process.exit(-1)
  process.exit(0)