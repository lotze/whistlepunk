redis_builder = require '../../lib/redis_builder'
Filter = require '../../lib/filter/filter'
should = require 'should'
async = require 'async'

describe 'Filter', ->
  beforeEach (done) ->
    @redis = redis_builder('whistlepunk')
    @redis.flushdb done
    @validator1 = { validates: -> true }
    @validator2 = { validates: -> true }
    @validators = [@validator1, @validator2]
    @times =
      oneHour: 1000 * 60 * 60
      oneDay: 1000 * 60 * 60 * 24
    @backwardDelta = @times.oneDay
    @forwardDelta = @times.oneHour
    @filter = new Filter(@redis, @validators, @backwardDelta, @forwardDelta)
    @event = {"name": "event", "timestamp": 1348186752000, "userId": "123"}
    @oldEventRecord = {"name": "event", "timestamp": 1, "userId": "456"}

  describe "#write", ->
    context "when all the validators prove the user is valid", ->
      beforeEach ->
        @validators[0].validates = -> true
        @validators[1].validates = -> true

      context "when the user isn't already in the store", ->
        it "stores the user in the valid users datastore", (done) ->
          @filter.on 'doneProcessing', =>
            @redis.zscore @filter.key, @event.userId, (err, reply) =>
              return done(err) if err?
              reply.should.eql(@event.timestamp.toString())
              done()
          @filter.write JSON.stringify(@event)

        context "and the event is a loginGuidChange event", ->
          it "stores the user's old and new GUIDs in the datastore", (done) ->
            @event.eventName = 'loginGuidChange'
            @event.oldGuid = 'oldGuid'
            @event.newGuid = 'newGuid'

            matchesScore = (obj, callback) =>
              @redis.zscore @filter.key, obj.id, (err, reply) =>
                return callback(false) if err?
                return callback(true) if reply == obj.score.toString()
                callback(false)

            @filter.on 'doneProcessing', =>
              records = [
                {id: @event.userId, score: @event.timestamp}
                {id: @event.oldGuid, score: @event.timestamp}
                {id: @event.newGuid, score: @event.timestamp}
              ]
              async.every records, matchesScore, (result) =>
                result.should.be.true
                done()
            @filter.write JSON.stringify(@event)

      context "when the user is already in the store with a lower score", ->
        beforeEach (done) ->
          @redis.zadd @filter.key, @event.timestamp - 1, @event.userId, done

        it "updates the score of the user to the latest timestamp", (done) ->
          @filter.on 'doneProcessing', =>
            @redis.zscore @filter.key, @event.userId, (err, reply) =>
              return done(err) if err?
              reply.should.eql(@event.timestamp.toString())
              done()
          @filter.write JSON.stringify(@event)

      context "when the user is already in the store with a higher score", ->
        beforeEach (done) ->
          @redis.zadd @filter.key, @event.timestamp + 1, @event.userId, done

        it "keeps the user's higher score", (done) ->
          @filter.on 'doneProcessing', =>
            @redis.zscore @filter.key, @event.userId, (err, reply) =>
              return done(err) if err?
              reply.should.eql((@event.timestamp + 1).toString())
              done()
          @filter.write JSON.stringify(@event)

    context "when none of the validators prove the user is valid", ->
      beforeEach ->
        @validators[0].validates = -> false
        @validators[1].validates = -> false

      it "does not store the user in the valid users datastore", (done) ->
        @filter.on 'doneProcessing', =>
          @redis.zscore @filter.key, @event.userId, (err, reply) ->
            return done(err) if err?
            should.not.exist(reply)
            done()
        @filter.write JSON.stringify(@event)

    context "when there are old users in the datastore", (done) ->
      beforeEach (done) ->
        @redis.zadd @filter.key, @oldEventRecord.timestamp, @oldEventRecord.userId, done

      it "removes users older than @delta from the datastore", ->
        @filter.on 'doneProcessing', =>
          @redis.zscore @filter.key, @oldEventRecord.userId, (err, reply) =>
            should.not.exist reply
        @filter.write JSON.stringify(@event)

  describe "#isValid", ->
    context "when the user is in the datastore", ->
      beforeEach (done) ->
        @redis.zadd @filter.key, @event.timestamp - @times.oneDay + @times.oneHour, @event.userId, done

      it "returns true", ->
        @filter.isValid JSON.stringify(@event), (valid) ->
          valid.should.be.true

    context "when the user is in not in the datastore", ->
      it "returns false", ->
        @filter.isValid JSON.stringify(@event), (valid) ->
          valid.should.be.false
