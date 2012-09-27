should = require("should")
assert = require("assert")
async = require("async")
IOSWorker = require("../workers/ios_worker")
Foreman = require('../lib/foreman')
Redis = require("../lib/redis")
DbLoader = require("../lib/db_loader")

dbloader = new DbLoader()
foreman = new Foreman()

describe "an ios worker", ->
  describe "after processing events from an ipad user", ->
    before (done) ->
      async.series [
        (cb) => foreman.init cb
        (cb) => foreman.clearDatabase cb
        (cb) => foreman.addWorker('ios_worker', new IOSWorker(foreman), cb)
        (cb) => foreman.processFile "test/log/ios.json", cb
      ], (err, results) =>
        foreman.callbackWhenClear(done)

    it "results in a user in all objects", (done) ->
      dbloader.db().query().select([ "object_id" ]).from("all_objects").where("object_type = ?", [ "user" ]).execute (error, rows, columns) ->
        if error
          console.log "ERROR: " + error
          return done(error)
        assert.equal rows.length, 1
        done()

    it "results in a user in olap_users", (done) ->
      dbloader.db().query().select([ "id" ]).from("olap_users").execute (error, rows, columns) ->
        if error
          console.log "ERROR: " + error
          done error
        assert.equal rows.length, 1
        done()

    it "results in a user created in the appropriate day/month", (done) ->
      dbloader.db().query("select day, week, month from olap_users join users_created_at on olap_users.id = users_created_at.user_id").execute (error, rows, columns) ->
        if error
          console.log "ERROR: " + error
          done error
        assert.equal rows.length, 1
        assert.equal rows[0].day, "2012-09-26"
        assert.equal rows[0].month, "2012-09-01"
        done()

    it "results in a user with a source of ipad app", (done) ->
      dbloader.db().query("select source from olap_users join sources_users on olap_users.id = sources_users.user_id order by source desc").execute (error, rows, columns) ->
        if error
          console.log "ERROR: " + error
          done error
        assert.equal rows.length, 1
        assert.equal rows[0].source, "ipad app"
        done()