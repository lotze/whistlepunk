_ = require 'underscore'
redis_builder = require '../../lib/redis_builder'
RedisWriter = require '../../lib/filter/redis_writer'
should = require 'should'

describe 'RedisWriter', ->
  beforeEach (done) ->
    @redis = redis_builder('whistlepunk')
    @redis.flushdb done
    @redisWriter = new RedisWriter(@redis, "example_destination")
    @event = {"name": "event", "timestamp": 1348186752000, "userId": "123"}

  context "when given data", ->

    it "should save data to redis", (done) ->
      @redisWriter.on "doneProcessing", =>
        @redis.lpop @redisWriter.key, (err, reply) =>
          should.not.exist err
          reply.should.eql(JSON.stringify @event)
          done()
      @redisWriter.write JSON.stringify @event