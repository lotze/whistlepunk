redis_builder = require '../../lib/redis_builder'
BacklogProcessor = require '../../lib/filter/backlog_processor'
async = require 'async'
sinon = require 'sinon'

describe 'Backlog Processor', ->

  beforeEach (done) ->
    @delta = 1000 * 60 * 60
    @redis = redis_builder('whistlepunk')
    @redis.flushdb done
    @filter = {}
    @processor = new BacklogProcessor(@redis, @delta, @filter)

  describe "#write", ->
    it "processes the event", ->
      spy = sinon.spy @processor, "processEvents"
      @processor.write('{"name": "event", "timestamp": 8600}')
      spy.calledOnce.should.be.true

    it "processes from the timestamp in the event", ->
      spy = sinon.spy @processor, "processEvents"
      @processor.write('{"name": "event", "timestamp": 8600}')
      spy.calledOnce.should.be.true
      spy.firstCall.calledWith(8600).should.be.true

    it "does not process if it is already processing", ->
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
          spy.calledThrice.should.be.true
          spy.getCall(0).calledWith(sourceEvents[3]).should.be.true
          spy.getCall(1).calledWith(sourceEvents[2]).should.be.true
          spy.getCall(2).calledWith(sourceEvents[1]).should.be.true
          done()
        @processor.processEvents now

  describe "#processEvent", ->
    it "emits a data event with 'valid' set to true if it is valid according to the filter", (done) ->
      @filter.isValid = (event, cb) -> cb(true)

      event = '{"time_desc": "now", "timestamp": 8600}'
      @processor.on 'data', (valid, event) =>
        valid.should.be.true
        event.should.eql event
        done()

      @processor.processEvent event

    it "emits a data event with 'valid' set to true if it is valid according to the filter", (done) ->
      @filter.isValid = (event, cb) -> cb(false)

      event = '{"time_desc": "now", "timestamp": 8600}'
      @processor.on 'data', (valid, event) =>
        valid.should.be.false
        event.should.eql event
        done()

      @processor.processEvent event