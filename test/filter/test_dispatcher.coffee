_ = require 'underscore'
async = require 'async'
redis_builder = require '../../lib/redis_builder'
Dispatcher = require '../../lib/filter/dispatcher'

describe 'Dispatcher', ->
  beforeEach (done) ->
    @redis = redis_builder('distillery')
    @dispatcher = new Dispatcher(redis_builder('distillery'))
    @redis.flushdb done

  # Warning: this test fails after the first run when using
  # cake spec:watch. I cannot figure out why for the life of me--
  # it looks like test pollution from the prior runs, but
  # console.log output shows extremely non-deterministic behavior
  # that makes no sense to me. [BT]
  it "streams data from the distillery list", (done) ->
    sourceEvents = ['an_event', 'another_event', 'a_third_event']
    targetEvents = []

    @dispatcher.on 'error', (err) ->
      done(err)
    @dispatcher.on 'data', (data) ->
      targetEvents.push data
      if sourceEvents.length == targetEvents.length
        if _.difference(sourceEvents, targetEvents).length == 0
          done()

    async.forEachSeries sourceEvents, @redis.lpush.bind(@redis, @dispatcher.key)

  context "#destroy", ->
    it "emits a single 'end' event", (done) ->
      endEmitted = false
      @dispatcher.on 'end', =>
        if endEmitted
          done(new Error('too many end events'))
        else
          endEmitted = true
          done()
      @dispatcher.destroy()

    it "emits a single 'close' event when redis is closed", (done) ->
      closeEmitted = false
      @dispatcher.on 'close', =>
        if closeEmitted
          done(new Error('too many close events'))
        else
          closeEmitted = true
          done()
      @dispatcher.destroy()

    it "sets the stream's readable property to false", ->
      @dispatcher.destroy()
      @dispatcher.readable.should.be.false
