should = require("should")
assert = require("assert")
async = require("async")
Foreman = require('../lib/foreman')
ShareWorker = require("../workers/share_worker")
UnionRep = require("../lib/union_rep")
Redis = require("../lib/redis")
DbLoader = require("../lib/db_loader")

dbloader = new DbLoader()
foreman = new Foreman()

describe "a share worker", ->
  describe "after processing share events", ->
    before (done) ->
      async.series [
        (cb) => foreman.init cb
        (cb) => foreman.clearDatabase cb
        (cb) => foreman.addWorker('share_worker', new ShareWorker(foreman), cb)
        (cb) => dbloader.db().query("INSERT INTO olap_users (id) VALUES ('effective_sharer'),('incoming_nonmember'),('incoming_member'),('sad_sharer'),('incoming_invite_requested_member');").execute cb
        (cb) => foreman.processFile "test/log/shares.json", cb
      ], (err, results) =>
        foreman.callbackWhenClear(done)

    it "should result in three shares and two sharers", (done) ->
      dbloader.db().query("select count(*) as shares, count(distinct sharing_user_id) as sharers from shares").execute (error, rows, columns) ->
        if error
          console.log "ERROR: " + error
          return done(error)
        assert.equal rows[0]['sharers'], 2
        assert.equal rows[0]['shares'], 3
        done()

    it "should result in sad_sharer sharing twice, with no incoming users", (done) ->
      dbloader.db().query("select num_visits, num_members from shares where sharing_user_id = 'sad_sharer'").execute (error, rows, columns) ->
        if error
          console.log "ERROR: " + error
          return done(error)
        assert.equal rows.length, 2
        assert.equal rows[0]['num_visits'], 0
        assert.equal rows[0]['num_members'], 0
        assert.equal rows[1]['num_visits'], 0
        assert.equal rows[1]['num_members'], 0
        done()

    it "should result in no incoming members for sad_sharer", (done) ->
      dbloader.db().query("select members_from_shares from olap_users where id = 'sad_sharer'").execute (error, rows, columns) ->
        if error
          console.log "ERROR: " + error
          return done(error)
        assert.equal rows[0]['members_from_shares'], 0
        done()

    it "should result in effective_sharer sharing once, with three incoming users, one of whom becomes a member and one of whom becomes an invite_requested_member", (done) ->
      dbloader.db().query("select num_visits, num_members, num_invite_requested_members from shares where sharing_user_id = 'effective_sharer'").execute (error, rows, columns) ->
        if error
          console.log "ERROR: " + error
          return done(error)
        assert.equal rows.length, 1
        assert.equal rows[0]['num_visits'], 3
        assert.equal rows[0]['num_members'], 1
        assert.equal rows[0]['num_invite_requested_members'], 1
        done()

    it "should result in one incoming member for effective_sharer", (done) ->
      dbloader.db().query("select members_from_shares from olap_users where id = 'effective_sharer'").execute (error, rows, columns) ->
        if error
          console.log "ERROR: " + error
          return done(error)
        assert.equal rows[0]['members_from_shares'], 1
        done()

    it "should result in three users not sharing at all", (done) ->
      dbloader.db().query("select count(*) as num_nonsharers from olap_users where shares_created=0").execute (error, rows, columns) ->
        if error
          console.log "ERROR: " + error
          return done(error)
        assert.equal rows[0]['num_nonsharers'], 3
        done()
