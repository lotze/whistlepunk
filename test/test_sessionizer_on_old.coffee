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
  describe "after processing old session events", ->
    before (done) ->
      unionRep = new UnionRep(1)
      fileProcessorHelper = new FileProcessorHelper(unionRep)
      worker = new Sessionizer(fileProcessorHelper)
      client = redis.createClient(config.redis.port, config.redis.host)
      finalMessage = JSON.parse('{"eventName":"request","userId":"finale","timestamp":9980170,"service":"service","ip":"1.2.3.4","referrer":"/","requestUri":"/","userAgent":"Chrome"}')
      client.flushdb (err, results) ->
        unionRep.addWorker('worker_being_tested', worker)
        
        fileProcessorHelper.clearDatabase (err, results) =>
          fileProcessorHelper.db.query("INSERT INTO olap_users (id) VALUES ('joe_active_four'),('close_two'),('bounce'),('just_once');").execute (err, results) =>
            worker.init (err, results) =>
              fileProcessorHelper.processFile "test/log/sessions.json", =>
                worker.dataProvider.measure 'user', "joe_active_four", 80170, 'better_measure', null, '', 1, =>
                  fileProcessorHelper.processMessage(finalMessage)
                  if unionRep.total == 0
                    done()
                  else
                    unionRep.once 'drain', =>
                      done()
  
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
  
    it "should record 'returned' measurements for user metrics on the sessions they occurred in", (done) ->
      fileProcessorHelper.db.query("select count(distinct all_measurements.object_id) as num_measured_sessions, count(*) as num_measures from all_measurements join all_objects on all_measurements.object_id = all_objects.object_id where all_measurements.object_type='session' and all_objects.object_type='session'").execute (error, rows, columns) ->
        if error
          console.log "ERROR: " + error
          return done(error)
        assert.equal rows[0]['num_measured_sessions'], 1
        assert.equal rows[0]['num_measures'], 1
        done()
    
    # it "should record the next-day return of users returning on their next local day"
    
