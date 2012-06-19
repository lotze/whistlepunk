should = require("should")
assert = require("assert")
async = require("async")
Foreman = require('../lib/foreman')
DauWorker = require("../workers/dau_worker")
MembershipStatusWorker = require("../workers/membership_status_worker")
FirstRequestWorker = require("../workers/first_request")
Redis = require("../lib/redis")

foreman = new Foreman()

describe "a dau worker", ->
  describe "with a member worker, processing 60 days of member activity", ->
    before (done) ->
      this.timeout(10000);
      Redis.getClient (err, client) =>
        return done(err) if err?
        @client = client
        foreman.init (err, result) =>
          return done(err) if err?
      
          async.series [
            (cb) => foreman.clearDatabase cb
            (cb) => foreman.addWorker('dau_worker', new DauWorker(foreman), cb)
            (cb) => foreman.addWorker('membership_status_worker', new MembershipStatusWorker(foreman), cb)
            (cb) => foreman.addWorker('first_request_worker', new FirstRequestWorker(foreman), cb)
            (cb) => foreman.processFile "test/log/dau_member.json", cb
          ], (err, results) =>
            foreman.callbackWhenClear(done)
  
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
      this.timeout(10000);
      Redis.getClient (err, client) =>
        return done(err) if err?
        @client = client
        foreman.init (err, result) =>
          return done(err) if err?      
          async.series [
            (cb) => foreman.clearDatabase cb
            (cb) => foreman.addWorker('dau_worker', new DauWorker(foreman), cb)
            (cb) => foreman.addWorker('membership_status_worker', new MembershipStatusWorker(foreman), cb)
            (cb) => foreman.addWorker('first_request_worker', new FirstRequestWorker(foreman), cb)
            (cb) => foreman.processFile "test/log/dau_visitor.json", cb
          ], (err, results) =>
            foreman.callbackWhenClear(done)
  
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
