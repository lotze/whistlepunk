Stream = require 'stream'
redis_builder = require '../../lib/redis_builder'
BacklogFiller = require '../../lib/filter/backlog_filler'

describe 'Backlog Filler', ->
  beforeEach (done) ->
    @createRedis = ->
      redis_builder('whistlepunk')
    @dispatcher = new Stream()
    @backlogFiller = new BacklogFiller(@createRedis())
    @dispatcher.pipe(@backlogFiller)

    @redis = @createRedis()
    @redis.flushdb done

  it "should chuck stuff into the backlog", (done) ->

    targetData = [
      '{"some": "one", "timestamp": 100}'
      '{"some": "three", "timestamp": 300}'
      '{"some": "two", "timestamp": 200}'
    ]
    eventsAdded = 0
    @backlogFiller.on 'close', =>
      @redis.zrange @backlogFiller.key, 0, 2, 'WITHSCORES', (err, reply) ->
        return done(err) if err?
        reply.length.should.eql(6) # two elements per event; one for event JSON, one for score [BT/BD]
        [reply1, score1, reply2, score2, reply3, score3] = reply
        JSON.parse(targetData[0]).timestamp.toString().should.eql score1
        JSON.parse(targetData[2]).timestamp.toString().should.eql score2
        JSON.parse(targetData[1]).timestamp.toString().should.eql score3
        reply1.should.eql targetData[0]
        reply2.should.eql targetData[2]
        reply3.should.eql targetData[1]
        done()

    for event in targetData
      @dispatcher.emit 'data', event
    @dispatcher.emit 'end'

  it "should withstand and ignore invalid json, continue entering valid json into store", (done) ->
    @backlogFiller.on 'close', =>
      @redis.zrange @backlogFiller.key, 0, 2, (err, reply) ->
        reply.length.should.eql(1)
        event = JSON.parse reply[0]
        event.foo.should.eql 'bar'
        done(err)

    @dispatcher.emit 'data', '{{{some invalid JSON'
    @dispatcher.emit 'data', JSON.stringify({ foo: "bar", timestamp: 100 })
    @dispatcher.emit 'end'

  describe "#write", ->
    it "should emit an error if it is not writable", (done) ->
      backlogFiller = new BacklogFiller(@createRedis())
      backlogFiller.on 'close', ->
        backlogFiller.on 'error', (err) ->
          done()
        backlogFiller.write('{"test": "ing"}')
      backlogFiller.end()
