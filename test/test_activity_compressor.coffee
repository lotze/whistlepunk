should = require("should")
assert = require("assert")
async = require("async")
FileProcessorHelper = require('../lib/file_processor_helper')
fileProcessorHelper = null
LearnistTranslatorWorker = require("../workers/learnist_translator")
ActivityCompressor = require("../workers/activity_compressor")
UnionRep = require("../lib/union_rep")
config = require("../config")
Redis = require("../lib/redis")
Db = require('mongodb').Db
Connection = require('mongodb').Connection
Server = require('mongodb').Server

describe "an activity compressor worker", ->
  describe "after processing user events", ->
    before (done) ->
      unionRep = new UnionRep(1)
      Redis.getClient (err, client) =>
        done(err) if err?
        fileProcessorHelper = new FileProcessorHelper(unionRep, client)
        worker = new ActivityCompressor(fileProcessorHelper)
        all_lines_read_in = false
        drained = false
        unionRep.addWorker('worker_being_tested', worker)
        activity_compressor_worker = new ActivityCompressor(fileProcessorHelper)
        learnist_translator_worker = new LearnistTranslatorWorker(fileProcessorHelper)
        fileProcessorHelper.clearDatabase (err, results) =>
          unionRep.addWorker('activity_compressor', activity_compressor_worker)
          unionRep.addWorker('learnist_translator', learnist_translator_worker)
          async.series [
            (cb) => activity_compressor_worker.init cb
            (cb) => learnist_translator_worker.init cb
            (cb) => fileProcessorHelper.processFile "test/log/user_activity.json", cb
          ], (err, results) =>
            if unionRep.total == 0
              done(err, results)
            else
              unionRep.once 'drain', =>
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
