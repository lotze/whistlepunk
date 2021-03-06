should = require("should")
assert = require("assert")
async = require("async")
Foreman = require('../lib/foreman')
LearnistTranslator = require("../workers/learnist_translator")
Redis = require("../lib/redis")
config = require('../config')
DbLoader = require("../lib/db_loader")

dbloader = new DbLoader()

describe "a learnist translator worker", ->
  describe "after processing viewedLearning events", ->
    before (done) ->
      foreman = new Foreman()
      async.series [
        (cb) => foreman.init cb
        (cb) => foreman.clearDatabase cb
        (cb) => foreman.addWorker('learnist_translator', new LearnistTranslator(foreman), cb)
        (cb) => foreman.processFile "test/log/learning_viewed.json", cb
      ], (err, results) =>
        foreman.callbackWhenClear(done)

    it "should result in correct timeseries entries", (done) ->
      async.parallel [
        (cb) => dbloader.db().query("select * from timeseries where measure_name = 'viewed_learning' and aggregation_level = 'day'").execute (err, rows, cols) =>
          cb(err, rows)
        (cb) => dbloader.db().query("select * from timeseries where measure_name = 'viewed_learning' and aggregation_level = 'month'").execute (err, rows, cols) =>
          cb(err, rows)
        (cb) => dbloader.db().query("select * from timeseries where measure_name = 'viewed_learning' and aggregation_level = 'year'").execute (err, rows, cols) =>
          cb(err, rows)
        (cb) => dbloader.db().query("select * from timeseries where measure_name = 'viewed_learning' and aggregation_level = 'total'").execute (err, rows, cols) =>
          cb(err, rows)
      ], (queryErr, mappedRows) =>
        [byDay, byMonth, byYear, byTotal] = mappedRows
        byDay.length.should.eql 10, "byDay length #{byDay.length}"
#        assert.equal byDay.length, 10, "ByDay incorrect"
        async.forEach byDay, (dailyValue, dailyCb) =>
          assert.equal dailyValue.amount, 1, "Loop dayValue incorrect"
          dailyCb(null)
        assert.equal byMonth.length, 5, "byMonth length incorrect"
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


    it "should result in correct all_measurements entries", (done) ->
      async.parallel [
        (cb) => dbloader.db().query("select * from all_measurements where measure_name = 'viewed_learning' and object_id = 'joe_active_four' and object_type='user'").execute (err, rows, cols) =>
          cb(err, rows)
        (cb) => dbloader.db().query("select * from all_measurements where measure_name = 'viewed_learning' and object_id = '1' and object_type='board'").execute (err, rows, cols) =>
          cb(err, rows)
        (cb) => dbloader.db().query("select * from all_measurements where measure_name = 'viewed_learning' and object_id = '2' and object_type='board'").execute (err, rows, cols) =>
          cb(err, rows)
      ], (queryErr, mappedRows) =>
        [byUser , byFirstBoard , bySecondBoard] = mappedRows
        assert.equal byUser.length, 2, "byUser length error"
        async.forEach byUser, (viewedNumber, viewedCb) =>
          assert.equal viewedNumber.amount, 5, "Loop viewedNumber amount error"
          viewedCb(null)
        assert.equal byFirstBoard.length, 1, "byFirstBoard length error"
        assert.equal byFirstBoard[0].amount, 5
        assert.equal bySecondBoard.length, 1
        assert.equal bySecondBoard[0].amount, 5
        done()

  describe "after processing createdBoard events", ->
    before (done) ->
      foreman = new Foreman()
      async.series [
        (cb) => foreman.init cb
        (cb) => foreman.clearDatabase cb
        (cb) => foreman.addWorker('learnist_translator', new LearnistTranslator(foreman), cb)
        (cb) => dbloader.db().query("INSERT INTO olap_users (id) VALUES ('joe_active_four');").execute cb
        (cb) => foreman.processFile "test/log/board_creation.json", cb
      ], (err, results) =>
        foreman.callbackWhenClear(done)

    it "should result in the user creating ten boards", (done) ->
      dbloader.db().query("select boards_created from olap_users").execute (error, rows, columns) ->
        return done(error) if error?
        assert.equal rows.length, 1
        assert.equal rows[0]['boards_created'], 10
        done()

    it "should result in correct timeseries entries", (done) ->
      async.parallel [
        (cb) => dbloader.db().query("select * from timeseries where measure_name = 'created_board' and aggregation_level = 'day'").execute (err, rows, cols) =>
          cb(err, rows)
        (cb) => dbloader.db().query("select * from timeseries where measure_name = 'created_board' and aggregation_level = 'month'").execute (err, rows, cols) =>
          cb(err, rows)
        (cb) => dbloader.db().query("select * from timeseries where measure_name = 'created_board' and aggregation_level = 'year'").execute (err, rows, cols) =>
          cb(err, rows)
        (cb) => dbloader.db().query("select * from timeseries where measure_name = 'created_board' and aggregation_level = 'total'").execute (err, rows, cols) =>
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
