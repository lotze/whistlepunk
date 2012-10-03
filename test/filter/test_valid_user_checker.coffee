redis_builder = require '../../lib/redis_builder'
ValidUserChecker = require '../../lib/filter/valid_user_checker'
should = require 'should'
async = require 'async'

describe 'ValidUserChecker', ->
  beforeEach (done) ->
    @redis = redis_builder('whistlepunk')
    @redis.flushdb done
    @times =
      oneHour: 1000 * 60 * 60
      oneDay: 1000 * 60 * 60 * 24
    @checker = new ValidUserChecker(@redis)
    @event = {"name": "event", "timestamp": 1348186752000, "userId": "123"}

  describe "#isValid", ->
    context "when the user is in the datastore", ->
      beforeEach (done) ->
        @redis.zadd @checker.key, @event.timestamp - @times.oneDay + @times.oneHour, @event.userId, done

      it "returns true", ->
        @checker.isValid JSON.stringify(@event), (valid) ->
          valid.should.be.true

    context "when the user is in not in the datastore", ->
      it "returns false", ->
        @checker.isValid JSON.stringify(@event), (valid) ->
          valid.should.be.false
