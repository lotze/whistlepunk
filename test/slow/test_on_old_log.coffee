should = require("should")
assert = require("assert")
async = require("async")
FileProcessorHelper = require('../lib/file_processor_helper')
Sessionizer = require("../workers/sessionizer")
UnionRep = require("../lib/union_rep")
redis = require("redis")
config = require('../config')
unionRep = new UnionRep(1000)
fileProcessorHelper = null

describe "a sessionizer worker", ->
  describe "after processing old session events", ->
    before (done) ->
      fileProcessorHelper = new FileProcessorHelper(unionRep)
      worker = new Sessionizer(fileProcessorHelper)
      client = redis.createClient(config.redis.port, config.redis.host)
      client.flushdb (err, results) ->
        unionRep.addWorker('worker_being_tested', worker)
        fileProcessorHelper.clearDatabase (err, results) =>
          worker.init (err, results) =>
            done()

    it "should finish and not throw errors", (done) ->
      this.timeout(45000);
      fileProcessorHelper.processFile "test/log/learnist.log.old", =>
        if unionRep.total == 0
          done()
        else
          unionRep.once 'drain', =>
            done()
