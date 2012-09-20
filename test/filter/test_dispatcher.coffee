_ = require 'underscore'
redis_builder = require '../../lib/redis_builder'
Dispatcher = require '../../lib/filter/dispatcher'

describe 'Dispatcher', ->
  it "streams data from the distillery list", (done) ->
    redis = redis_builder('distillery')
    dispatcher = new Dispatcher(redis_builder('distillery'))
    redis.flushdb (err, success) ->

      sourceEvents = ['an_event', 'another_event', 'a_third_event']
      targetEvents = []

      dispatcher.on 'error', (err) ->
        done(err)
      dispatcher.on 'data', (data) ->
        targetEvents.push data
        if sourceEvents.length == targetEvents.length
          if _.difference(sourceEvents, targetEvents).length == 0
            done()

      for evt in sourceEvents
        redis.lpush "distillery:#{process.env.NODE_ENV}:msg_queue", evt, ->