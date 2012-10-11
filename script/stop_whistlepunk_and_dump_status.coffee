#!/usr/bin/env coffee

process.env.NODE_ENV ?= 'development'

require('coffee-script')

config = require('../config')
Redis = require("../lib/redis")

child_process = require('child_process')
moment = require 'moment'
fs = require('fs')
util = require('util')
async = require('async')
logger = require('../lib/logger')

# stop whistlepunk
# dump SQL
# dump redis
# dump mongo
# start whistlepunk

redis = null

# get timestamp for backup
now = moment(new Date())
timestamp = now.format("YYYY-MM-DD")

logger.info("backing up to #{config.backup.dir}/#{timestamp}:")

process.on 'SIGKILL', ->
  process.exit(0)

process.on 'SIGINT', ->
  process.exit(0)

async.series [
  (cb) =>
    logger.info("creating backup directory...")
    child_process.exec "mkdir -p #{config.backup.dir}/#{timestamp}", cb
  (cb) =>
    # get redis client
    logger.info("getting redis client...")
    Redis.getClient (err, client) =>
      client.select config.redis.db_num  if config.redis.db_num
      return cb(err) if err?
      redis = client
      cb()
  (cb) =>
    # stop whistlepunk
    if (process.env.NODE_ENV == 'production' || process.env.NODE_ENV == 'staging')
      logger.info("stopping whistlepunk...")
      child_process.exec "sudo stop whistlepunk_#{process.env.NODE_ENV}", cb
    else
      cb()
  (cb) =>
    # dump data
    async.parallel [
      (dump_cb) =>
        async.series [
          (mysql_cb) => 
            logger.info("dumping mysql...")
            child_process.exec "mysqldump -u#{config.db.user} -p#{config.db.password} -h#{config.db.hostname} #{config.db.database} > #{config.backup.dir}/#{timestamp}/mysql.sql", mysql_cb
          (mysql_cb) => 
            logger.info("gzipping mysql...")
            child_process.exec "gzip #{config.backup.dir}/#{timestamp}/mysql.sql", mysql_cb
        ], dump_cb
      (dump_cb) =>
        logger.info("saving redis...")
        redis.save (err, result) =>
          return dump_cb(err) if err?
          logger.info("copying redis backup...")
          # copy redis dump file to backup dir
          input_stream = fs.createReadStream("#{config.backup.redis_rdb_dir}/dump.rdb")
          output_stream = fs.createWriteStream("#{config.backup.dir}/#{timestamp}/redis.rdb")
          util.pump input_stream, output_stream, dump_cb
      (dump_cb) =>
        logger.info("dumping mongodb...")
        # dump mongo
        child_process.exec "mongodump --host #{config.mongo_db_server} --db #{config.mongo_db_name} --out=#{config.backup.dir}/#{timestamp}/mongo", dump_cb
    ], cb
  (cb) =>
    if (process.env.NODE_ENV == 'production' || process.env.NODE_ENV == 'staging')
      logger.info("starting whistlepunk...")
      child_process.exec "sudo start whistlepunk_#{process.env.NODE_ENV}", cb
    else
      cb()
  (cb) =>
    if (process.env.NODE_ENV == 'production' || process.env.NODE_ENV == 'staging')
      logger.info("uploading to s3...")
      child_process.exec "s3cmd --no-delete-removed sync #{config.backup.dir}/#{timestamp} s3://com.grockit.whistlepunk/backups/#{process.env.NODE_ENV}/#{timestamp}/", cb
    else
      cb()
], (err, results) =>
  logger.error("Error was #{err}, results were #{results}") if err?
  process.exit(0)