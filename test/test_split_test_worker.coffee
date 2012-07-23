should = require("should")
assert = require("assert")
async = require("async")
Foreman = require('../lib/foreman')
SplitTestWorker = require("../workers/split_test_worker")
UnionRep = require("../lib/union_rep")
Redis = require("../lib/redis")
DbLoader = require("../lib/db_loader")

dbloader = new DbLoader()

describe "a split test worker", ->
  describe "after processing split test events", ->
    before (done) ->
      foreman = new Foreman()
      async.series [
        (cb) => foreman.init cb
        (cb) => foreman.clearDatabase cb
        (cb) => foreman.addWorker('split_test_worker', new SplitTestWorker(foreman), cb)
        (cb) => foreman.processFile "test/log/split_tests.json", cb
      ], (err, results) =>
        foreman.callbackWhenClear(done)

    it "should result in two asignments, one to each side of the test", (done) ->
      dbloader.db().query("select participant_id, assignment from split_test_assignments").execute (error, rows, columns) ->
        if error
          console.log "ERROR: " + error
          return done(error)
        assert.equal rows.length, 2
        assert rows[0]['assignment'] != rows[1]['assignment']
        done()