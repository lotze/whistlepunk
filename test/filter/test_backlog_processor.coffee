redis_builder = require '../../lib/redis_builder'
BacklogProcessor = require '../../lib/filter/backlog_processor'
ValidUserChecker = require '../../lib/filter/valid_user_checker'
async = require 'async'
sinon = require 'sinon'

describe 'Backlog Processor', ->

  beforeEach (done) ->
    @delta = 1000 * 60 * 60
    @redis = redis_builder('whistlepunk')
    @redis.flushdb done
    @filter = {}
    @checker = new ValidUserChecker(redis_builder('whistlepunk'))
    @processor = new BacklogProcessor(@redis, @delta, @filter, @checker)

  describe "#write", ->
    it "processes the event", ->
      spy = sinon.spy @processor, "processEvents"
      @processor.write('{"name": "event", "timestamp": 8600}')
      spy.calledOnce.should.be.true

    it "processes from the timestamp in the event", ->
      spy = sinon.spy @processor, "processEvents"
      @processor.write('{"name": "event", "timestamp": 8600}')
      spy.calledOnce.should.be.true
      spy.getCall(0).calledWith(8600).should.be.true

    it "does not process immediately if it is already processing", ->
      spy = sinon.spy @processor, "processEvents"
      @processor.write('{"name": "event", "timestamp": 8600}')
      @processor.write('{"name": "event", "timestamp": 8700}')
      spy.calledOnce.should.be.true

    it "does not process when paused", ->
      spy = sinon.spy @processor, "processEvents"
      @processor.pause()
      @processor.write('{"name": "event", "timestamp": 8600}')
      spy.called.should.be.false

    it "resumes processing after being resumed", ->
      spy = sinon.spy @processor, "processEvents"
      @processor.pause()
      @processor.write('{"name": "event", "timestamp": 8600}')
      spy.called.should.be.false
      @processor.resume()
      spy.called.should.be.false
      @processor.write('{"name": "event", "timestamp": 8600}')
      spy.called.should.be.true

    it "queues events to be processed if it's already processing", ->
      spy = sinon.spy @processor, "processEvents"
      @processor.write('{"name": "event", "timestamp": 8600}')
      @processor.write('{"name": "event", "timestamp": 8700}')
      spy.calledOnce.should.be.true
      @processor.queuedTimestamp.should.eql 8700

  describe "#processEvents", ->
    it "processes events from the backlog in order, up to @delta ago", (done) ->
      oneHour = 1000 * 60 * 60
      oneDay = oneHour * 24

      now = new Date().getTime()
      oneHourAgo = new Date().getTime() - oneHour
      oneDayAgo = new Date().getTime() - oneDay

      sourceEvents = [
        '{"time_desc": "now", "timestamp": ' + now + '}'
        '{"time_desc": "oneHourAgo", "timestamp": ' + oneHourAgo + '}'
        '{"time_desc": "twoHoursAgo", "timestamp": ' + (oneHourAgo - oneHour) + '}'
        '{"time_desc": "oneDayAgo", "timestamp": ' + oneDayAgo + '}'
      ]

      spy = sinon.stub(@processor, 'processEvent').yields()

      async.forEach sourceEvents, (event, callback) =>
        @redis.zadd @processor.key, JSON.parse(event).timestamp, event, callback
      , (err) =>
        return done(err) if err?

        @processor.on 'doneProcessing', ->

          # I have gotten some failures on this test that feel
          # are race-condition-y, but I have not been able to
          # isolate the issue. Since Redis is single-threaded
          # and we're using async to ensure we're done adding events
          # before the assertions are made, I'm not sure what's up. [BT]
          spy.calledThrice.should.be.true
          spy.getCall(0).calledWith(sourceEvents[3]).should.be.true
          spy.getCall(1).calledWith(sourceEvents[2]).should.be.true
          spy.getCall(2).calledWith(sourceEvents[1]).should.be.true
          done()
        @processor.processEvents now

    it "processes queued events after processing", (done) ->
      spy = sinon.spy @processor, "processEvents"
      @processor.on 'doneProcessing', =>
        spy.calledTwice.should.be.true
        spy.getCall(0).calledWith(8600).should.be.true
        spy.getCall(1).calledWith(8700).should.be.true
        done()
      @processor.queuedTimestamp = 8700
      @processor.processEvents 8600

    it "removes processed events from Redis", (done) ->
      @filter.isValid = (event, cb) -> cb(true)

      events = [
        '{"eventName": "event1", "timestamp": 100}'
        '{"eventName": "event2", "timestamp": 200}'
        '{"eventName": "event2", "timestamp": 300}'
      ]

      @processor.on 'doneProcessing', =>
        @redis.zcard @processor.key, (err, reply) =>
          return done(err) if err?
          reply.should.eql(1)
          done()

      addToRedis = (event, cb) => @redis.zadd @processor.key, JSON.parse(event).timestamp, event, cb
      async.forEach events, addToRedis, (err) =>
        return done(err) if err?

        @processor.delta = 0
        @processor.processEvents 200

  describe "#processEvent", ->
    it "emits a data event with a 'isValidUser' property set to true if it is valid according to the filter", (done) ->
      @checker.isValid = (event, cb) -> cb(true)

      testEventJson = '{"time_desc": "now", "timestamp": 8600}'
      testEvent = JSON.parse testEventJson

      @processor.on 'data', (eventJson) =>
        event = JSON.parse eventJson
        event.isValidUser.should.be.true
        event.timestamp.should.eql testEvent.timestamp
        done()

      @processor.processEvent testEventJson

    it "emits a data event with a 'isValidUser' property set to true if it is valid according to the filter", (done) ->
      @checker.isValid = (event, cb) -> cb(false)

      testEventJson = '{"time_desc": "now", "timestamp": 8600}'
      testEvent = JSON.parse testEventJson

      @processor.on 'data', (eventJson) =>
        event = JSON.parse eventJson
        event.isValidUser.should.be.false
        event.timestamp.should.eql testEvent.timestamp
        done()

      @processor.processEvent testEventJson
