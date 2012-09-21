_ = require 'underscore'
redis_builder = require '../../lib/redis_builder'
LogWriter = require '../../lib/filter/log_writer'
should = require 'should'

describe 'LogWriter', ->
  beforeEach (done) ->
    @redis = redis_builder('filtered')
    @redis.flushdb done
    @logWriter = new LogWriter(@redis, "example_destination")
    @event = {"name": "event", "timestamp": 1348186752000, "userId": "123"}

  context "when given data", ->

    it "should save data to redis", (done) ->
      @logWriter.on "doneProcessing", (err, reply) =>
        should.not.exist err
        @redis.rpop @logWriter.key, (err, reply) =>
          should.not.exist err
          should.exist reply
          done()
      @logWriter.write JSON.stringify @event