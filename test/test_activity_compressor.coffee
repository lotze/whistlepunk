should = require("should")
assert = require("assert")
async = require("async")
Foreman = require('../lib/foreman')
LearnistTranslatorWorker = require("../workers/learnist_translator")
ActivityCompressor = require("../workers/activity_compressor")
config = require("../config")
Redis = require("../lib/redis")
Db = require('mongodb').Db
Connection = require('mongodb').Connection
Server = require('mongodb').Server

describe "an activity compressor worker", ->
  describe "after processing user events", ->
    before (done) ->
      foreman = new Foreman()
      foreman.init (err, result) =>
        done(err) if err?
        all_lines_read_in = false
        drained = false
        activity_compressor_worker = new ActivityCompressor(foreman)
        learnist_translator_worker = new LearnistTranslatorWorker(foreman)
        foreman.clearDatabase (err, results) =>
          async.series [
            (cb) => foreman.addWorker('activity_compressor', activity_compressor_worker, cb)
            (cb) => foreman.addWorker('learnist_translator', learnist_translator_worker, cb)
            (cb) => foreman.processFile "test/log/user_activity.json", cb
          ], (err, results) =>
            if foreman.unionRep.total == 0
              done(err, results)
            else
              foreman.unionRep.once 'drain', =>
                done(err, results)

    it "should result in three entries in mongo, for two users", (done) ->
      mongo = new Db(config.mongo_db_name, new Server(config.mongo_db_server, config.mongo_db_port, {}), {})
      mongo.open (err, db) =>
        mongo.collection 'compressedActivity', (err, compressedActivity) =>
          done(err) if err?
          compressedActivity.find().toArray (err, results) =>
            results.length.should.eql 3
            results[0].userId.should.eql 'double_user'
            results[1].userId.should.eql 'double_user'
            results[2].userId.should.eql 'single_user'
            done(err, results)
