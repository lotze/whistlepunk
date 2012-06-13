should = require("should")
assert = require("assert")
async = require("async")
FirstRequest = require("../workers/first_request")
Foreman = require('../lib/foreman')
Redis = require("../lib/redis")
DbLoader = require("../lib/db_loader")

dbloader = new DbLoader()
foreman = new Foreman()

describe "a first_request worker", ->
  describe "#country", ->
    before (done) ->
      async.series [
        (cb) => dbloader.db().query("TRUNCATE TABLE geoip").execute cb
        (cb) =>       
          dbloader.db().query("INSERT INTO geoip (start_ip, end_ip, ip_start, ip_end, country_code, country_name, ip_poly) VALUES ('10.0.0.1', '10.0.0.1', 167772161,       167772161, 'LV', 'Latveria', GEOMFROMWKB(POLYGON(LINESTRING(
            /* clockwise, 4 points and back to 0 */
            POINT(167772161, -1), /* 0, top left */
            POINT(167772161,   -1), /* 1, top right */
            POINT(167772161,    1), /* 2, bottom right */
            POINT(167772161,  1), /* 3, bottom left */
            POINT(167772161, -1)  /* 0, back to start */
          ))))").execute cb
        ], (err, results) =>
          done(arguments...)
    it "gets the correct country for the test IP address", (done) =>
      worker = new FirstRequest(foreman)
      worker.country '10.0.0.1', (err, country) =>
        assert.equal country, 'Latveria'
        done(err)
  
  describe "#locationId", ->
    before (done) ->
      async.series [
        (cb) => dbloader.db().query("TRUNCATE TABLE ip_location_lookup").execute cb
        (cb) =>       
          dbloader.db().query("INSERT INTO ip_location_lookup (ip_start, ip_end, location_id, ip_poly) VALUES (167772161, 167772161, 1337, GEOMFROMWKB(POLYGON(LINESTRING(
            /* clockwise, 4 points and back to 0 */
            POINT(167772161, -1), /* 0, top left */
            POINT(167772161,   -1), /* 1, top right */
            POINT(167772161,    1), /* 2, bottom right */
            POINT(167772161,  1), /* 3, bottom left */
            POINT(167772161, -1)  /* 0, back to start */
          ))))").execute cb
        ], (err, results) =>
          done(arguments...)
    it "gets the correct locationId for the test IP address", (done) =>
      worker = new FirstRequest(foreman)
      worker.locationId '10.0.0.1', (err, locationId) =>
        assert.equal locationId, 1337
        done(err)
  

  describe "after processing a firstRequest event", ->
    before (done) ->
      async.series [
        (cb) => foreman.init cb
        (cb) => foreman.clearDatabase cb
        (cb) => foreman.addWorker('first_request_worker', new FirstRequest(foreman), cb)
        (cb) => foreman.processFile "test/log/first_sessions.json", cb
      ], (err, results) =>
        if foreman.unionRep.total == 0
          done()
        else
          foreman.unionRep.once 'drain', =>
            done()

    it "results in three users in all_objects", (done) ->
      dbloader.db().query().select([ "object_id" ]).from("all_objects").where("object_type = ?", [ "user" ]).execute (error, rows, columns) ->
        if error
          console.log "ERROR: " + error
          return done(error)
        assert.equal rows.length, 3
        done()

    it "results in three users in olap_users", (done) ->
      dbloader.db().query().select([ "id" ]).from("olap_users").execute (error, rows, columns) ->
        if error
          console.log "ERROR: " + error
          done error
        assert.equal rows.length, 3
        done()

    it "results in three users created in the appropriate day/week/month", (done) ->
      dbloader.db().query("select day, week, month from olap_users join users_created_at on olap_users.id = users_created_at.user_id").execute (error, rows, columns) ->
        if error
          console.log "ERROR: " + error
          done error
        assert.equal rows.length, 3
        assert.equal rows[0].day, "1969-12-31"
        assert.equal rows[0].week, "1969-12-29"
        assert.equal rows[0].month, "1969-12-01"
        assert.equal rows[1].day, "1970-01-01"
        assert.equal rows[1].week, "1969-12-29"
        assert.equal rows[1].month, "1970-01-01"
        assert.equal rows[2].day, "1969-12-31"
        assert.equal rows[2].week, "1969-12-29"
        assert.equal rows[2].month, "1969-12-01"
        done()

    it "results in one user from google, one unknown, and one from hatchery", (done) ->
      dbloader.db().query("select source from olap_users join sources_users on olap_users.id = sources_users.user_id").execute (error, rows, columns) ->
        if error
          console.log "ERROR: " + error
          done error
        assert.equal rows.length, 3
        assert.equal rows[0].source, "Unknown"
        assert.equal rows[1].source, "hatchery.cc"
        assert.equal rows[2].source, "google.com"
        done()