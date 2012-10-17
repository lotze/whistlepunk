#!/usr/bin/env coffee

process.env.NODE_ENV ?= 'development'

require('coffee-script')

Foreman = require('../lib/foreman')
Db = require('mongodb').Db
Connection = require('mongodb').Connection
Server = require('mongodb').Server

config = require('../config')
Redis = require("../lib/redis")
redis = require('redis')
local_redis_client = null

child_process = require('child_process')
fs = require('fs')
util = require('util')
async = require('async')
logger = require('../lib/logger')

# load data from the dump
# - load SQL
# - load redis
# - load mongo

# get timestamp for backup to use; should be in the format "YYYY-MM-DD"
timestamp = process.argv[2]

logger.info("reloading from #{config.backup.dir}/#{timestamp}:")

process.on 'SIGKILL', ->
  process.exit(0)

process.on 'SIGINT', ->
  process.exit(0)

process.on 'uncaughtException', (e) ->
  logger.error("UNCAUGHT EXCEPTION: ", e, e.stack)
  process.exit(0)

whistlepunk_running = false

async.series [
  (cb) =>
    # get redis client
    logger.info("getting redis client...")
    Redis.getClient (err, client) =>
      return cb(err) if err?
      local_redis_client = client
      cb()
  (cb) =>
    # load data
    async.parallel [
      (load_cb) =>
        # load SQL
        async.series [
          (mysql_cb) =>
            logger.info("gunzipping mysql...")
            child_process.exec "gunzip #{config.backup.dir}/#{timestamp}/mysql.sql.gz", mysql_cb
          (mysql_cb) =>
            logger.info("loading mysql...")
            child_process.exec "mysql -u#{config.db.user} -p#{config.db.password} -h#{config.db.hostname} #{config.db.database} < #{config.backup.dir}/#{timestamp}/mysql.sql", (err, results) =>
              logger.info("...finished loading mysql")
              mysql_cb()
          (mysql_cb) =>
            logger.info("gzipping mysql...")
            child_process.exec "gzip #{config.backup.dir}/#{timestamp}/mysql.sql", mysql_cb
        ], load_cb
          load_cb(err, results)
      (load_cb) =>
        async.series [
          # shut down redis, copy file, restart redis
          (redis_cb) =>
            logger.info("stopping redis...")
            if (process.env.NODE_ENV == 'development')
              child_process.exec "launchctl unload -w ~/Library/LaunchAgents/homebrew.mxcl.redis.plist", redis_cb
            else
              child_process.exec "sudo service redis-server stop", redis_cb
          (redis_cb) =>
            logger.info("copying redis backup...")
            # copy redis dump file from backup dir
            child_process.exec "sudo cp -f #{config.backup.dir}/#{timestamp}/redis.rdb #{config.backup.redis_rdb_dir}/dump.rdb", redis_cb
          (redis_cb) =>
            logger.info("starting redis...")
            if (process.env.NODE_ENV == 'development')
              child_process.exec "launchctl load -w ~/Library/LaunchAgents/homebrew.mxcl.redis.plist", redis_cb
            else
              child_process.exec "sudo service redis-server start", redis_cb
        ], (err, results) =>
          logger.info("...finished loading redis")
          load_cb(err, results)
      (load_cb) =>
        # load mongo
        async.series [
          (mongo_cb) =>
            logger.info("dropping mongodb...")
            mongo = new Db(config.mongo_db_name, new Server(config.mongo_db_server, config.mongo_db_port, {}), {})
            mongo.open (err, db) =>
              mongo.dropDatabase(mongo_cb)
          (mongo_cb) =>
            logger.info("loading mongodb...")
            child_process.exec "mongorestore --host #{config.mongo_db_server} --db #{config.mongo_db_name} #{config.backup.dir}/#{timestamp}/mongo/#{config.mongo_db_name}", mongo_cb
        ], (err, results) =>
          logger.info("...finished loading mongo")
          load_cb(err, results)
    ], (err, results) =>
      logger.info("...finished loading all data; ready to catch up using logs")
      cb(err, results)
], (err, results) =>
  if err?
    logger.error("Error was #{err}, results were #{results}")
    process.exit(-1)
  process.exit(0)
