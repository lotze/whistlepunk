should = require("should")
assert = require("assert")
async = require("async")
FileProcessorHelper = require('../lib/file_processor_helper')
Sessionizer = require("../workers/sessionizer")
UnionRep = require("../lib/union_rep")
redis = require("redis")
config = require('../config')

fileProcessorHelper = null

describe "a sessionizer worker", ->
  # describe "when given real-world session events", ->
  #   before (done) ->
  #     try
  #       processed = 0
  #       client = redis.createClient(config.redis.port, config.redis.host)
  #       client.flushdb (err, results) ->
  #         worker = new Sessionizer(fileProcessorHelper)
  #         worker.on "done", (e, r) ->
  #           processed++
  #           done()  if processed is 47
  #         fileProcessorHelper.clearDatabase (err, results) ->
  #           worker.init (err, results) ->
  #             fileProcessorHelper.processFile "test/log/long.log"
  #     catch e
  #       console.log("ERROR:", e)
  #       done(e)
  # 
  #   it "should not have caused an exception", (done) ->
  #     done()

  describe "after processing session events", ->
    before (done) ->
      processed = 0
      client = redis.createClient(config.redis.port, config.redis.host)
      client.flushdb (err, results) ->
        unionRep = new UnionRep()
        fileProcessorHelper = new FileProcessorHelper(unionRep)
        worker = new Sessionizer(fileProcessorHelper)
        unionRep.addWorker('sessionizer', worker)        
        worker.on "done", (e, r) ->
          processed++
          done() if processed is 52
        fileProcessorHelper.clearDatabase (err, results) ->
          fileProcessorHelper.db.query("INSERT INTO olap_users (id) VALUES ('joe_active_four'),('close_two'),('bounce'),('just_once');").execute (err, results) ->
            worker.init (err, results) ->
              fileProcessorHelper.processFile "test/log/sessions.json"

    it "should result in the users having four, two, one, and one sessions each", (done) ->
      fileProcessorHelper.db.query("select num_sessions from olap_users order by num_sessions").execute (error, rows, columns) ->
        if error
          console.log "ERROR: " + error
          return done(error)
        assert.equal rows[0]['num_sessions'], 1
        assert.equal rows[1]['num_sessions'], 1
        assert.equal rows[2]['num_sessions'], 2
        assert.equal rows[3]['num_sessions'], 4
        done()

    it "should result in the users having 4000, 2000, 1000, and 0 seconds on site each", (done) ->
      fileProcessorHelper.db.query("select seconds_on_site from olap_users order by seconds_on_site").execute (error, rows, columns) ->
        if error
          console.log "ERROR: " + error
          return done(error)
        assert.equal rows[0]['seconds_on_site'], 0
        assert.equal rows[1]['seconds_on_site'], 1000
        assert.equal rows[2]['seconds_on_site'], 2000
        assert.equal rows[3]['seconds_on_site'], 4000
        done()

    it "should have eight session objects in all_objects", (done) ->
      fileProcessorHelper.db.query("select count(*) as num_sessions from all_objects where object_type = 'session'").execute (error, rows, columns) ->
        if error
          console.log "ERROR: " + error
          return done(error)
        assert.equal rows[0]['num_sessions'], 8
        done()

    it "should record measurements for user metrics on the sessions they occurred in", (done) ->
      fileProcessorHelper.db.query("select count(*) as num_measured_sessions from all_measurements join all_objects on all_measurements.object_id = all_objects.object_id where all_measurements.object_type='session' and all_objects.object_type='session'").execute (error, rows, columns) ->
        if error
          console.log "ERROR: " + error
          return done(error)
        assert.equal rows[0]['num_measured_sessions'], 2
        done()
    
    # it "should record the next-day return of users returning on their next local day"
    
