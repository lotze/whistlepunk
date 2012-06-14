should = require("should")
assert = require("assert")
async = require("async")
Foreman = require('../lib/foreman')
Redis = require("../lib/redis")
worker = null
MembershipStatusWorker = require("../workers/membership_status_worker")
DbLoader = require("../lib/db_loader")

dbloader = new DbLoader()
foreman = new Foreman()

describe "a membership status worker", ->
  describe "after processing membership status events", ->
    before (done) ->
      async.series [
        (cb) => foreman.init cb
        (cb) => foreman.clearDatabase cb
        (cb) => foreman.addWorker('membership_status', new MembershipStatusWorker(foreman), cb)
        (cb) => dbloader.db().query("INSERT INTO olap_users (id) VALUES ('super_member'),('non-member'),('regular member');").execute cb
        (cb) => foreman.processFile "test/log/member_status.json", cb
      ], (err, results) =>
        foreman.callbackWhenClear(done)

    it "should update regular member's name and email address", (done) ->
      dbloader.db().query("select name, email from olap_users where id='regular member'").execute (error, rows, columns) ->
        if error
          console.log "ERROR: " + error
          return done(error)
        assert.equal rows[0]['name'], 'Regular Joe'
        assert.equal rows[0]['email'], 'joe@test.com'
        done()

    it "should have two members in all_objects", (done) ->
      dbloader.db().query("select count(*) as num_members from all_objects where object_type = 'member'").execute (error, rows, columns) ->
        if error
          console.log "ERROR: " + error
          return done(error)
        assert.equal rows[0]['num_members'], 2
        done()

    it "should have one super member in all_objects", (done) ->
      dbloader.db().query("select count(*) as num_members from all_objects where object_type = 'super_member'").execute (error, rows, columns) ->
        if error
          console.log "ERROR: " + error
          return done(error)
        assert.equal rows[0]['num_members'], 1
        done()

    it "should have two users marked as having become members in users_membership_status_at", (done) ->
      dbloader.db().query("select count(*) as num_members from olap_users join users_membership_status_at on users_membership_status_at.user_id = olap_users.id where users_membership_status_at.status='member'").execute (error, rows, columns) ->
        if error
          console.log "ERROR: " + error
          return done(error)
        assert.equal rows[0]['num_members'], 2
        done()

    it "should have one user marked as having become a super member in users_membership_status_at", (done) ->
      dbloader.db().query("select count(*) as num_members from olap_users join users_membership_status_at on users_membership_status_at.user_id = olap_users.id where users_membership_status_at.status='super_member'").execute (error, rows, columns) ->
        if error
          console.log "ERROR: " + error
          return done(error)
        assert.equal rows[0]['num_members'], 1
        done()

    it "should have one user in olap_users marked as a member", (done) ->
      dbloader.db().query("select count(*) as num_members from olap_users where status='member'").execute (error, rows, columns) ->
        if error
          console.log "ERROR: " + error
          return done(error)
        assert.equal rows[0]['num_members'], 1
        done()

    it "should have one user in olap_users marked as a super member", (done) ->
      dbloader.db().query("select count(*) as num_members from olap_users where status='super_member'").execute (error, rows, columns) ->
        if error
          console.log "ERROR: " + error
          return done(error)
        assert.equal rows[0]['num_members'], 1
        done()
      
                        
      