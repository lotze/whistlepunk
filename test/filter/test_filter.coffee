redis_builder = require '../../lib/redis_builder'
Filter = require '../../lib/filter/filter'
should = require 'should'

describe 'Filter', ->
  beforeEach (done) ->
    @redis = redis_builder('whistlepunk')
    @redis.flushdb done
    @validator1 = { isValid: -> true }
    @validator2 = { isValid: -> true }
    @validators = [@validator1, @validator2]
    @filter = new Filter(@redis, @validators, 1000 * 60 * 60 * 24)
    @event = {"name": "event", "timestamp": 1348186752000, "userId": "123"}
    @oldEventRecord = {"name": "event", "timestamp": 1, "userId": "456"}

  describe "#write", ->
    context "when all the validators prove the user is valid", ->
      beforeEach ->
        @validators[0].isValid = -> true
        @validators[1].isValid = -> true

      context "when the user isn't already in the store", ->
        it "stores the user in the valid users datastore", (done) ->
          @filter.on 'doneProcessing', =>
            @redis.zscore @filter.key, @event.userId, (err, reply) =>
              return done(err) if err?
              reply.should.eql(@event.timestamp.toString())
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

    context "when one or more of the validators fail to prove the user is valid", ->
      beforeEach ->
        @validators[0].isValid = -> true
        @validators[1].isValid = -> false

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

      it "removes users older then 24 hours from the datastore", ->
        @filter.on 'doneProcessing', =>
          @redis.zscore @filter.key, @oldEventRecord.userId, (err, reply) =>
            should.not.exist reply
        @filter.write JSON.stringify(@event)

  describe "#isValid", ->
    it "returns true if the user is found in the datastore for 24-hours around the event timestamp", ->

    it "returns false if not that stuff", ->
