should = require("should")
assert = require("assert")
async = require("async")
FileProcessorHelper = require('../lib/file_processor_helper')
Sessionizer = require("../workers/sessionizer")
MemberStatusWorker = require("../workers/membership_status_worker")
LearnistTranslatorWorker = require("../workers/learnist_translator")
UnionRep = require("../lib/union_rep")
redis = require("redis")
config = require('../config')

fileProcessorHelper = null

describe "a sessionizer and learnist translator worker", ->
  describe "when processing a request and an event causing a user measurement", ->
    before (done) ->
      unionRep = new UnionRep(1)
      fileProcessorHelper = new FileProcessorHelper(unionRep)
      sessionizer_worker = new Sessionizer(fileProcessorHelper)
      learnist_translator_worker = new LearnistTranslatorWorker(fileProcessorHelper)
      client = redis.createClient(config.redis.port, config.redis.host)
      client.flushdb (err, results) ->
        unionRep.addWorker('sessionizer', sessionizer_worker)
        unionRep.addWorker('learnist_translator', learnist_translator_worker)
        
        async.series [
          (cb) => fileProcessorHelper.clearDatabase cb
          (cb) => sessionizer_worker.init cb
          (cb) => learnist_translator_worker.init cb
          (cb) => fileProcessorHelper.processFile "test/log/tiny_session_test.json", cb
        ], (err, results) =>
          if unionRep.total == 0
            done()
          else
            unionRep.once 'drain', =>
              done()

    it "should store the measurement on the user and the session", (done) ->
      fileProcessorHelper.db.query("select object_type, amount from all_measurements where measure_name = 'tagged'").execute (error, rows, columns) ->
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
      unionRep = new UnionRep(1)
      fileProcessorHelper = new FileProcessorHelper(unionRep)
      sessionizer_worker = new Sessionizer(fileProcessorHelper)
      member_status_worker = new MemberStatusWorker(fileProcessorHelper)
      client = redis.createClient(config.redis.port, config.redis.host)
      finalMessage = JSON.parse('{"eventName":"request","userId":"finale","timestamp":9980170,"service":"service","ip":"1.2.3.4","referrer":"/","requestUri":"/","userAgent":"Chrome"}')
      client.flushdb (err, results) ->
        unionRep.addWorker('sessionizer', sessionizer_worker)
        unionRep.addWorker('member_status', member_status_worker)
        
        async.series [
          (cb) => fileProcessorHelper.clearDatabase cb
          (cb) => fileProcessorHelper.db.query("INSERT INTO olap_users (id) VALUES ('joe_active_four'),('close_two'),('bounce'),('just_once');").execute cb
          (cb) => sessionizer_worker.init cb
          (cb) => member_status_worker.init cb
          (cb) => fileProcessorHelper.processFile "test/log/sessions.json", cb
          (cb) => sessionizer_worker.dataProvider.measure 'user', "joe_active_four", 80170, 'better_measure', null, '', 1, cb
          (cb) => 
            fileProcessorHelper.processMessage finalMessage
            cb()
        ], (err, results) =>
          if unionRep.total == 0
            done()
          else
            unionRep.once 'drain', =>
              done()
  
    it "should record 'upgraded_to_member' measurements for joe and his session", (done) ->
      fileProcessorHelper.db.query("select object_type, amount from all_measurements where measure_name = 'upgraded_to_member'").execute (error, rows, columns) ->
        if error
          console.log "ERROR: " + error
          return done(error)
        assert.equal rows.length, 2
        assert.equal rows[0]['amount'], 1
        assert.equal rows[1]['amount'], 1
        done()

    it "should record 'better_measure' measurements for joe and his session", (done) ->
      fileProcessorHelper.db.query("select object_type, amount from all_measurements where measure_name = 'better_measure'").execute (error, rows, columns) ->
        if error
          console.log "ERROR: " + error
          return done(error)
        assert.equal rows.length, 2
        assert.equal rows[0]['amount'], 1
        assert.equal rows[1]['amount'], 1
        done()
        
    it "should record 'better_measure' once in timeline", (done) ->
      fileProcessorHelper.db.query("select aggregation_level, amount from timeseries where measure_name = 'better_measure'").execute (error, rows, columns) ->
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
      fileProcessorHelper.db.query("select aggregation_level, amount from timeseries where measure_name = 'upgraded_to_member'").execute (error, rows, columns) ->
        if error
          console.log "ERROR: " + error
          return done(error)
        assert.equal rows.length, 4
        assert.equal rows[0]['amount'], 1
        assert.equal rows[1]['amount'], 1
        assert.equal rows[2]['amount'], 1
        assert.equal rows[3]['amount'], 1
        done()
