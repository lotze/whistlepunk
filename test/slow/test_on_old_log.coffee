should = require("should")
assert = require("assert")
async = require("async")
FileProcessorHelper = require('../lib/file_processor_helper')
Sessionizer = require("../workers/sessionizer")
UnionRep = require("../lib/union_rep")
unionRep = new UnionRep(1000)
fileProcessorHelper = null

describe "a sessionizer worker", ->
  describe "after processing old session events", ->
    before (done) ->
      fileProcessorHelper = new FileProcessorHelper unionRep, (err, result) =>
        worker = new Sessionizer(fileProcessorHelper)
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
