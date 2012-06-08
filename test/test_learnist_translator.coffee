should = require("should")
assert = require("assert")
async = require("async")
FileProcessorHelper = require('../lib/file_processor_helper')
LearnistTranslator = require("../workers/learnist_translator")
UnionRep = require("../lib/union_rep")
Redis = require("../lib/redis")
config = require('../config')

fileProcessorHelper = null

describe "a learnist translator worker", ->
  describe "after processing createdBoard events", ->
    before (done) ->
      unionRep = new UnionRep(1)
      Redis.getClient (err, client) =>
        done(err) if err?
        fileProcessorHelper = new FileProcessorHelper(unionRep, client)
        worker = new LearnistTranslator(fileProcessorHelper)
        fileProcessorHelper.clearDatabase (err, results) ->
          unionRep.addWorker('worker_being_tested', worker)
          fileProcessorHelper.clearDatabase (err, results) =>
            fileProcessorHelper.db.query("INSERT INTO olap_users (id) VALUES ('joe_active_four');").execute (err, results) =>
              worker.init (err, results) =>
                fileProcessorHelper.processFile "test/log/board_creation.json", =>
                  if unionRep.total == 0
                    done()
                  else
                    unionRep.once 'drain', =>
                      done()

    it "should result in the user creating ten boards", (done) ->
      fileProcessorHelper.db.query("select boards_created from olap_users").execute (error, rows, columns) ->
        return done(error) if error?
        assert.equal rows.length, 1
        assert.equal rows[0]['boards_created'], 10
        done()

    it "should result in correct timeseries entries", (done) ->
      async.parallel [
        (cb) => fileProcessorHelper.db.query("select * from timeseries where measure_name = 'created_board' and aggregation_level = 'day'").execute (err, rows, cols) =>
          cb(err, rows)
        (cb) => fileProcessorHelper.db.query("select * from timeseries where measure_name = 'created_board' and aggregation_level = 'month'").execute (err, rows, cols) =>
          cb(err, rows)
        (cb) => fileProcessorHelper.db.query("select * from timeseries where measure_name = 'created_board' and aggregation_level = 'year'").execute (err, rows, cols) =>
          cb(err, rows)
        (cb) => fileProcessorHelper.db.query("select * from timeseries where measure_name = 'created_board' and aggregation_level = 'total'").execute (err, rows, cols) =>
          cb(err, rows)
      ], (queryErr, mappedRows) =>
        [byDay, byMonth, byYear, byTotal] = mappedRows
        assert.equal byDay.length, 10
        async.forEach byDay, (dailyValue, dailyCb) =>
          assert.equal dailyValue.amount, 1
          dailyCb(null)
        assert.equal byMonth.length, 5
        assert.equal byMonth[0].amount, 5
        assert.equal byMonth[1].amount, 1
        assert.equal byMonth[2].amount, 1
        assert.equal byMonth[3].amount, 1
        assert.equal byMonth[4].amount, 2
        assert.equal byYear.length, 1
        assert.equal byYear[0].amount, 10
        assert.equal byTotal.length, 1
        assert.equal byTotal[0].amount, 10
        done()
