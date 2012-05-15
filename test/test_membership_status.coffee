should = require("should")
assert = require("assert")
async = require("async")
FileProcessorHelper = require("./file_processor_helper")
fileProcessorHelper = new FileProcessorHelper()
MembershipStatusWorker = require("../workers/membership_status_worker")

describe "a membership status worker", ->
  describe "after processing membership status events", ->
    before (done) ->
      processed = 0
      worker = new MembershipStatusWorker(fileProcessorHelper)
      worker.on "done", (e, r) ->
        processed++
        done()  if processed is 4
      fileProcessorHelper.clearDatabase (err, results) ->
        fileProcessorHelper.db.query("INSERT INTO olap_users (id) VALUES ('super_member'),('non-member'),('regular member');").execute (err, results) ->
          fileProcessorHelper.processFile "../metricizer/spec/log/member_status.log"

    it "should update regular member's name and email address", (done) ->
      fileProcessorHelper.db.query("select name, email from olap_users where id='regular member'").execute (error, rows, columns) ->
        if error
          console.log "ERROR: " + error
          return done(error)
        assert.equal rows[0]['name'], 'Regular Joe'
        assert.equal rows[0]['email'], 'joe@test.com'
        done()

    it "should have two members in all_objects", (done) ->
      fileProcessorHelper.db.query("select count(*) as num_members from all_objects where object_type = 'member'").execute (error, rows, columns) ->
        if error
          console.log "ERROR: " + error
          return done(error)
        assert.equal rows[0]['num_members'], 2
        done()

    it "should have one super member in all_objects", (done) ->
      fileProcessorHelper.db.query("select count(*) as num_members from all_objects where object_type = 'super_member'").execute (error, rows, columns) ->
        if error
          console.log "ERROR: " + error
          return done(error)
        assert.equal rows[0]['num_members'], 1
        done()

    it "should have two users marked as having become members in users_membership_status_at", (done) ->
      fileProcessorHelper.db.query("select count(*) as num_members from olap_users join users_membership_status_at on users_membership_status_at.user_id = olap_users.id where users_membership_status_at.status='member'").execute (error, rows, columns) ->
        if error
          console.log "ERROR: " + error
          return done(error)
        assert.equal rows[0]['num_members'], 2
        done()

    it "should have one user marked as having become a super member in users_membership_status_at", (done) ->
      fileProcessorHelper.db.query("select count(*) as num_members from olap_users join users_membership_status_at on users_membership_status_at.user_id = olap_users.id where users_membership_status_at.status='super_member'").execute (error, rows, columns) ->
        if error
          console.log "ERROR: " + error
          return done(error)
        assert.equal rows[0]['num_members'], 1
        done()

    it "should have one user in olap_users marked as a member", (done) ->
      fileProcessorHelper.db.query("select count(*) as num_members from olap_users where status='member'").execute (error, rows, columns) ->
        if error
          console.log "ERROR: " + error
          return done(error)
        assert.equal rows[0]['num_members'], 1
        done()

    it "should have one user in olap_users marked as a super member", (done) ->
      fileProcessorHelper.db.query("select count(*) as num_members from olap_users where status='super_member'").execute (error, rows, columns) ->
        if error
          console.log "ERROR: " + error
          return done(error)
        assert.equal rows[0]['num_members'], 1
        done()
      
                        
      