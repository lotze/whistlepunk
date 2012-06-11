should = require("should")
assert = require("assert")
async = require("async")
FileProcessorHelper = require('../lib/file_processor_helper')
fileProcessorHelper = null
DauWorker = require("../workers/dau_worker")
MembershipStatusWorker = require("../workers/membership_status_worker")
FirstRequestWorker = require("../workers/first_request")
UnionRep = require("../lib/union_rep")
Redis = require("../lib/redis")

describe "a dau worker", ->
  describe "with a member worker, processing 60 days of member activity", ->
    before (done) ->
      this.timeout(6000);
      unionRep = new UnionRep(1)
      Redis.getClient (err, client) =>
        return done(err) if err?
        @client = client
        fileProcessorHelper = new FileProcessorHelper(unionRep, client)
        dau_worker = new DauWorker(fileProcessorHelper)
        membership_status_worker = new MembershipStatusWorker(fileProcessorHelper)
        first_request_worker = new FirstRequestWorker(fileProcessorHelper)
        unionRep.addWorker('dau_worker', dau_worker)
        unionRep.addWorker('first_request_worker', first_request_worker)
        unionRep.addWorker('membership_status_worker', membership_status_worker)
      
        async.series [
          (cb) => fileProcessorHelper.clearDatabase cb
          (cb) => dau_worker.init cb
          (cb) => membership_status_worker.init cb
          (cb) => first_request_worker.init cb
          (cb) => fileProcessorHelper.processFile "test/log/dau_member.json", cb
        ], (err, results) =>
          if unionRep.total == 0
            done()
          else
            unionRep.once 'drain', =>
              done()

    it "should result in the first 30 days DAU being 1 member each", (done) ->
      @client.keys "dau:member:2012:06:*", (err, results) =>
        return done(err) if err?
        results.sort().length.should.equal(30)
        async.forEach results, (key_name) =>
          @client.scard key_name, (err, result) =>
            return done(err) if err?
            parseInt(result).should.equal(1)
        , (err) =>
          return done(err)
        return done()

    it "should result in the last 30 days DAU having 1-30 members each", (done) ->
      @client.keys "dau:member:2012:07:*", (err, results) =>
        return done(err) if err?
        results.sort().length.should.equal(30)
        async.forEach results, (key_name) =>
          @client.scard key_name, (err, result) =>
            return done(err) if err?
            parseInt(result).should.equal(parseInt(key_name.replace(/^dau:member:2012:07:0*/, "")))
        , (err) =>
          return done(err)
        return done()

  describe "with a member worker, processing 60 days of visitor activity", ->
    before (done) ->
      this.timeout(6000);
      unionRep = new UnionRep(1)
      Redis.getClient (err, client) =>
        return done(err) if err?
        @client = client
        fileProcessorHelper = new FileProcessorHelper(unionRep, client)
        dau_worker = new DauWorker(fileProcessorHelper)
        membership_status_worker = new MembershipStatusWorker(fileProcessorHelper)
        first_request_worker = new FirstRequestWorker(fileProcessorHelper)
        unionRep.addWorker('dau_worker', dau_worker)
        unionRep.addWorker('first_request_worker', first_request_worker)
        unionRep.addWorker('membership_status_worker', membership_status_worker)
      
        async.series [
          (cb) => fileProcessorHelper.clearDatabase cb
          (cb) => dau_worker.init cb
          (cb) => membership_status_worker.init cb
          (cb) => first_request_worker.init cb
          (cb) => fileProcessorHelper.processFile "test/log/dau_visitor.json", cb
        ], (err, results) =>
          if unionRep.total == 0
            done()
          else
            unionRep.once 'drain', =>
              done()
  
    it "should result in the first 30 days DAU being 1 visitor each", (done) ->
      @client.keys "dau:visitor:2012:06:*", (err, results) =>
        return done(err) if err?
        results.sort().length.should.equal(30)
        async.forEach results, (key_name) =>
          @client.scard key_name, (err, result) =>
            return done(err) if err?
            parseInt(result).should.equal(1)
        , (err) =>
          return done(err)
        return done()
  
    it "should result in the last 30 days DAU having 1-30 visitors each", (done) ->
      @client.keys "dau:visitor:2012:07:*", (err, results) =>
        return done(err) if err?
        results.sort().length.should.equal(30)
        async.forEach results, (key_name) =>
          @client.scard key_name, (err, result) =>
            return done(err) if err?
            parseInt(result).should.equal(parseInt(key_name.replace(/^dau:visitor:2012:07:0*/, "")))
        , (err) =>
          return done(err)
        return done()
