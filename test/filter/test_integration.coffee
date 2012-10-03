process.env.NODE_ENV ?= 'test'

fs = require 'fs'
path = require 'path'
_ = require 'underscore'
should = require 'should'
moment = require 'moment'
async = require 'async'
existsSync = fs.existsSync || path.existsSync

config = require '../../config'
redis_builder = require '../../lib/redis_builder'
Preprocessor = require '../../lib/filter/preprocessor'

now = new Date().getTime()
time = (modifications = {}) ->
  moment.unix(now).add(modifications).toDate().getTime()

users = (num) ->
  "user#{num}"

sourceEvents = [
  { eventName: 'request', userId: users(0), timestamp: time() }
  { eventName: 'request', userId: users(0), timestamp: time(seconds: 30) }
  { eventName: 'jsCharacteristics', userId: users(1), jsEnabled: true, timestamp: time(minutes: 1) }
  { eventName: 'request', userId: users(2), client: 'iPad app', timestamp: time(minutes: 2) }
  { eventName: 'request', userId: users(3), client: 'iPhone app', timestamp: time(minutes: 3) }
  { eventName: 'request', userId: users(4), timestamp: time(minutes: 4) }
  { eventName: 'login', userId: users(4), timestamp: time(minutes: 4, seconds: 5) }
  { eventName: 'trigger', userId: users(5), timestamp: time(hours: 1, minutes: 30) }
]

makeTargetEvents = (ids, valid, stringify = false) ->
  targetEvents = []
  for id in ids
    obj = _.clone(sourceEvents[id])
    obj.isValidUser = valid
    obj = JSON.stringify obj if stringify
    targetEvents.push obj
  targetEvents

describe "Filter integration", ->
  beforeEach ->
    for filePath in [config.logfile.valid_user_events, config.logfile.invalid_user_events]
      fs.unlinkSync filePath if existsSync filePath

  beforeEach (done) ->
    flushRedis = (redisName, cb) ->
      redis = redis_builder(redisName)
      redis.flushdb ->
        redis.quit cb

    redisNames = ['distillery', 'whistlepunk', 'filtered']
    async.forEach redisNames, flushRedis, done

  beforeEach (done) ->
    @preprocessor = new Preprocessor()
    @preprocessor.on 'close', done

    distilleryRedis = redis_builder('distillery')
    queueEvent = (event, cb) =>
      distilleryRedis.lpush @preprocessor.dispatcher.key, JSON.stringify(event), cb

    async.forEachSeries sourceEvents, queueEvent, =>
      process.nextTick @preprocessor.destroy

  it 'writes the correct events to the valid user events message queue', (done) ->
    redis = redis_builder('filtered')

    redis.lrange @preprocessor.redisWriter.key, 0, -1, (err, reply) ->
      return done(err) if err?
      reply.reverse() # Since we do LPUSHes into Redis, the oldest event is at the end of the array
      targetEvents = makeTargetEvents([2, 3, 4, 5, 6], true, true)
      difference = _.difference(reply, targetEvents)
      difference.length.should.eql 0
      done()

  it 'writes the correct events to the valid user events file', ->
    targetEvents = makeTargetEvents([2, 3, 4, 5, 6], true, true)
    file = config.logfile.valid_user_events
    data = fs.readFileSync file, 'utf8'
    data = data.split("\n").filter (line) -> line != ''
    difference = _.difference(data, targetEvents)
    difference.length.should.eql 0

  it 'writes the correct events to the invalid user events file', ->
    targetEvents = makeTargetEvents([0, 1], false, true)
    file = config.logfile.invalid_user_events
    data = fs.readFileSync file, 'utf8'
    data = data.split("\n").filter (line) -> line != ''
    difference = _.difference(data, targetEvents)
    difference.length.should.eql 0
