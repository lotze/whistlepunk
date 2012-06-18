should = require("should")
assert = require("assert")
async = require("async")
Foreman = require('../lib/foreman')
Sessionizer = require("../workers/sessionizer")
UnionRep = require("../lib/union_rep")
unionRep = new UnionRep(1000)
fileProcessorHelper = null

describe "a sessionizer worker", ->
  describe "after processing old session events", ->
    before (done) ->
      foreman = new Foreman
      foreman.init (err, result) =>
        worker = new Sessionizer(foreman)
        unionRep.addWorker('worker_being_tested', worker)
        foreman.clearDatabase (err, results) =>
          worker.init (err, results) =>
            done()

    it "should finish and not throw errors", (done) ->
      this.timeout(45000);
      foreman.processFile "test/log/learnist.log.old", =>
        if unionRep.total == 0
          done()
        else
          unionRep.once 'drain', =>
            done()
