should = require("should")
assert = require("assert")
async = require("async")
Foreman = require('../lib/foreman')
Sessionizer = require("../workers/sessionizer")
Redis = require("../lib/redis")
config = require('../config')
DbLoader = require("../lib/db_loader")
DataProvider = require('../lib/data_provider')

dbloader = new DbLoader()
foreman = new Foreman()
dataProvider = new DataProvider(foreman)

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

  describe "after processing current session events", ->
    before (done) ->
      finalMessage = JSON.parse('{"eventName":"request","userId":"finale","timestamp":999980170,"service":"service","ip":"1.2.3.4","referrer":"/","requestUri":"/","userAgent":"Chrome"}')
      async.series [
        (cb) => foreman.init cb
        (cb) => foreman.clearDatabase cb
        (cb) => foreman.addWorker('sessionizer', new Sessionizer(foreman), cb)
        (cb) => dbloader.db().query("INSERT INTO olap_users (id) VALUES ('joe_active_four'),('close_two'),('bounce'),('just_once');").execute cb
        (cb) => foreman.processFile "test/log/sessions.json", cb
        (cb) => dataProvider.measure 'user', "joe_active_four", 80170, 'better_measure', undefined, '', 1, cb
        (cb) => 
          foreman.processMessage(finalMessage)
          cb()
      ], (err, results) =>
        if foreman.unionRep.total == 0
          done()
        else
          foreman.unionRep.once 'drain', =>
            done()

    it "should result in the users having four, two, one, and one sessions each", (done) ->
      dbloader.db().query("select num_sessions from olap_users order by num_sessions").execute (error, rows, columns) ->
        if error
          console.log "ERROR: " + error
          return done(error)
        assert.equal rows[0]['num_sessions'], 1
        assert.equal rows[1]['num_sessions'], 1
        assert.equal rows[2]['num_sessions'], 2
        assert.equal rows[3]['num_sessions'], 4
        done()

    it "should result in the users having 4000, 2000, 1000, and 0 seconds on site each", (done) ->
      dbloader.db().query("select seconds_on_site from olap_users order by seconds_on_site").execute (error, rows, columns) ->
        if error
          console.log "ERROR: " + error
          return done(error)
        assert.equal rows[0]['seconds_on_site'], 0
        assert.equal rows[1]['seconds_on_site'], 1000
        assert.equal rows[2]['seconds_on_site'], 2000
        assert.equal rows[3]['seconds_on_site'], 4000
        done()

    it "should have eight session objects in all_objects", (done) ->
      dbloader.db().query("select count(*) as num_sessions from all_objects where object_type = 'session'").execute (error, rows, columns) ->
        if error
          console.log "ERROR: " + error
          return done(error)
        assert.equal rows[0]['num_sessions'], 8
        done()

    it "should record 'returned' measurements for user metrics on the sessions they occurred in", (done) ->
      dbloader.db().query("select count(distinct all_measurements.object_id) as num_measured_sessions, count(*) as num_measures from all_measurements join all_objects on all_measurements.object_id = all_objects.object_id where all_measurements.object_type='session' and all_objects.object_type='session'").execute (error, rows, columns) ->
        if error
          console.log "ERROR: " + error
          return done(error)
        assert.equal rows[0]['num_measured_sessions'], 1
        assert.equal rows[0]['num_measures'], 1
        done()
    
    # it "should record the next-day return of users returning on their next local day"