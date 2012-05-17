should = require("should")
assert = require("assert")
async = require("async")
FileProcessorHelper = require("./file_processor_helper")
fileProcessorHelper = new FileProcessorHelper()
ShareWorker = require("../workers/share_worker")

describe "a share worker", ->
  describe "after processing share events", ->
    before (done) ->
      processed = 0
      worker = new ShareWorker(fileProcessorHelper)
      worker.on "done", (e, r) ->
        processed++
        done()  if processed is 8
      fileProcessorHelper.clearDatabase (err, results) ->
        fileProcessorHelper.db.query("INSERT INTO olap_users (id) VALUES ('effective_sharer'),('incoming_nonmember'),('incoming_member'),('sad_sharer');").execute (err, results) ->
          worker.init ->
            fileProcessorHelper.processFile "../metricizer/spec/log/shares.log"

    it "should result in three shares and two sharers", (done) ->
      fileProcessorHelper.db.query("select count(*) as shares, count(distinct sharing_user_id) as sharers from shares").execute (error, rows, columns) ->
        if error
          console.log "ERROR: " + error
          return done(error)
        assert.equal rows[0]['sharers'], 2
        assert.equal rows[0]['shares'], 3
        done()

    it "should result in sad_sharer sharing twice, with no incoming users", (done) ->
      fileProcessorHelper.db.query("select num_visits, num_members from shares where sharing_user_id = 'sad_sharer'").execute (error, rows, columns) ->
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
      fileProcessorHelper.db.query("select members_from_shares from olap_users where id = 'sad_sharer'").execute (error, rows, columns) ->
        if error
          console.log "ERROR: " + error
          return done(error)
        assert.equal rows[0]['members_from_shares'], 0
        done()
        
    it "should result in effective_sharer sharing once, with two incoming users, one of whom becomes a member", (done) ->
      fileProcessorHelper.db.query("select num_visits, num_members from shares where sharing_user_id = 'effective_sharer'").execute (error, rows, columns) ->
        if error
          console.log "ERROR: " + error
          return done(error)
        assert.equal rows.length, 1
        assert.equal rows[0]['num_visits'], 2
        assert.equal rows[0]['num_members'], 1
        done()

    it "should result in one incoming member for effective_sharer", (done) ->
      fileProcessorHelper.db.query("select members_from_shares from olap_users where id = 'effective_sharer'").execute (error, rows, columns) ->
        if error
          console.log "ERROR: " + error
          return done(error)
        assert.equal rows[0]['members_from_shares'], 1
        done()
                
    it "should result in two users not sharing at all", (done) ->
      fileProcessorHelper.db.query("select count(*) as num_nonsharers from olap_users where shares_created=0").execute (error, rows, columns) ->
        if error
          console.log "ERROR: " + error
          return done(error)
        assert.equal rows[0]['num_nonsharers'], 2
        done()
                