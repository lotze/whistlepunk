should = require("should")
assert = require("assert")
async = require("async")
Foreman = require('../lib/foreman')
Sessionizer = require("../workers/sessionizer")
MemberStatusWorker = require("../workers/membership_status_worker")
LearnistTranslatorWorker = require("../workers/learnist_translator")
DbLoader = require("../lib/db_loader")
DataProvider = require('../lib/data_provider')

dbloader = new DbLoader()

describe "a sessionizer and learnist translator worker", ->
  describe "when processing a request and an event causing a user measurement", ->
    before (done) ->
      @foreman = new Foreman()
      @foreman.init (err, result) =>
        done(err) if err?
        async.series [
          (cb) => @foreman.clearDatabase cb
          (cb) => @foreman.addWorker('sessionizer_worker',new Sessionizer(@foreman),cb)
          (cb) => @foreman.addWorker('learnist_translator_worker',new LearnistTranslatorWorker(@foreman),cb)
          (cb) => @foreman.processFile "test/log/tiny_session_test.json", cb
        ], (err, results) =>
          if @foreman.unionRep.total == 0
            done(err, results)
          else
            @foreman.unionRep.once 'drain', =>
              done(err, results)

    it "should store the measurement on the user and the session", (done) ->
      dbloader.db().query("select object_type, amount from all_measurements where measure_name = 'tagged'").execute (error, rows, columns) ->
        if error
          console.log "ERROR: " + error
          return done(error)
        assert.equal rows.length, 2
        assert.equal rows[0]['amount'], 1
        assert.equal rows[1]['amount'], 1
        done()

describe "a sessionizer and membership status worker", ->
  describe "after processing old session events", ->
    before (done) ->
      @foreman = new Foreman()
      dataProvider = new DataProvider(@foreman)
      @foreman.init (err, result) =>
        done(err) if err?
        async.series [
          (cb) => @foreman.clearDatabase cb
          (cb) => dbloader.db().query("INSERT INTO olap_users (id) VALUES ('joe_active_four'),('close_two'),('bounce'),('just_once');").execute cb
          (cb) => @foreman.addWorker('sessionizer_worker', new Sessionizer(@foreman), cb)
          (cb) => @foreman.addWorker('learnist_translator_worker', new LearnistTranslatorWorker(@foreman), cb)
          (cb) => @foreman.addWorker('membership_status', new MemberStatusWorker(@foreman), cb)
          (cb) => @foreman.processFile "test/log/old_sessions.json", cb
          (cb) => dataProvider.measure 'user', "joe_active_four", 80170, 'better_measure', null, '', 1, cb
        ], (err, results) =>
          if @foreman.unionRep.total == 0
            done(err, results)
          else
            @foreman.unionRep.once 'drain', =>
              done(err, results)
  
    it "should record 'upgraded_to_member' measurements for joe and his session", (done) ->
      dbloader.db().query("select object_type, amount from all_measurements where measure_name = 'upgraded_to_member'").execute (error, rows, columns) ->
        if error
          console.log "ERROR: " + error
          return done(error)
        assert.equal rows.length, 2
        assert.equal rows[0]['amount'], 1
        assert.equal rows[1]['amount'], 1
        done()

    it "should record 'better_measure' measurements for joe and his session", (done) ->
      dbloader.db().query("select object_type, amount from all_measurements where measure_name = 'better_measure'").execute (error, rows, columns) ->
        if error
          console.log "ERROR: " + error
          return done(error)
        assert.equal rows.length, 2
        assert.equal rows[0]['amount'], 1
        assert.equal rows[1]['amount'], 1
        done()
        
    it "should record 'better_measure' once in timeline", (done) ->
      dbloader.db().query("select aggregation_level, amount from timeseries where measure_name = 'better_measure'").execute (error, rows, columns) ->
        if error
          console.log "ERROR: " + error
          return done(error)
        assert.equal rows.length, 4
        assert.equal rows[0]['amount'], 1
        assert.equal rows[1]['amount'], 1
        assert.equal rows[2]['amount'], 1
        assert.equal rows[3]['amount'], 1
        done()
      
    it "should record 'upgraded_to_member' once in timeline", (done) ->
      dbloader.db().query("select aggregation_level, amount from timeseries where measure_name = 'upgraded_to_member'").execute (error, rows, columns) ->
        if error
          console.log "ERROR: " + error
          return done(error)
        assert.equal rows.length, 4
        assert.equal rows[0]['amount'], 1
        assert.equal rows[1]['amount'], 1
        assert.equal rows[2]['amount'], 1
        assert.equal rows[3]['amount'], 1
        done()
