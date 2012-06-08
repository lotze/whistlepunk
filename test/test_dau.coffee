should = require("should")
assert = require("assert")
async = require("async")
FileProcessorHelper = require('../lib/file_processor_helper')
fileProcessorHelper = null
DauWorker = require("../workers/dau_worker")
UnionRep = require("../lib/union_rep")
Redis = require("../lib/redis")

describe "a dau worker", ->
  describe "after processing 60 days of events", ->
    before (done) ->
      unionRep = new UnionRep(1)
      Redis.getClient (err, client) =>
        done(err) if err?
        fileProcessorHelper = new FileProcessorHelper(unionRep, client)
        worker = new DauWorker(fileProcessorHelper)
        all_lines_read_in = false
        drained = false
        unionRep.addWorker('worker_being_tested', worker)
        Redis.getClient (err, client) =>
          @client = client
          fileProcessorHelper.clearDatabase (err, results) =>
            worker.init (err, results) =>
              fileProcessorHelper.processFile "test/log/dau.json", =>
                if unionRep.total == 0
                  done()
                else
                  unionRep.once 'drain', =>
                    done()

    it "should result in the first 30 days DAU being 1 each", (done) ->
      @client.keys "dau:2012:06:*", (err, results) =>
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
      @client.keys "dau:2012:07:*", (err, results) =>
        return done(err) if err?
        results.sort().length.should.equal(30)
        async.forEach results, (key_name) =>
          @client.scard key_name, (err, result) =>
            return done(err) if err?
            parseInt(result).should.equal(parseInt(key_name.replace(/^dau:2012:07:0*/, "")))
        , (err) =>
          return done(err)
        return done()
