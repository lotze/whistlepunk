process.env.NODE_ENV ?= 'test'

fs = require 'fs'
_ = require 'underscore'
should = require 'should'
moment = require 'moment'
async = require 'async'

config = require '../../config'
redis_builder = require '../../lib/redis_builder'

Dispatcher = require '../../lib/filter/dispatcher'
BacklogFiller = require '../../lib/filter/backlog_filler'
BacklogProcessor = require '../../lib/filter/backlog_processor'
Filter = require '../../lib/filter/filter'
RedisWriter = require '../../lib/filter/redis_writer'
LogWriter = require '../../lib/filter/log_writer'
Gate = require '../../lib/filter/gate'

JavaScriptEnabledValidator = require '../../lib/filter/validators/java_script_enabled_validator'
LoginValidator = require '../../lib/filter/validators/login_validator'
IosClientValidator = require '../../lib/filter/validators/ios_client_validator'

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
    for path in [config.logfile.valid_user_events, config.logfile.invalid_user_events]
      fs.unlinkSync path if fs.existsSync path

  beforeEach (done) ->
    flushRedis = (redisName, cb) ->
      redis = redis_builder(redisName)
      redis.flushdb ->
        redis.quit cb

    redisNames = ['distillery', 'whistlepunk', 'filtered']
    async.forEach redisNames, flushRedis, done

  beforeEach (done) ->
    userValidators    = [JavaScriptEnabledValidator, LoginValidator, IosClientValidator]

    dispatcher        = new Dispatcher(redis_builder('distillery'))
    backlogFiller     = new BacklogFiller(redis_builder('whistlepunk'))
    filter            = new Filter(redis_builder('whistlepunk'), userValidators, config.expirations.filterBackwardExpireDelay)
    backlogProcessor  = new BacklogProcessor(redis_builder('whistlepunk'), config.expirations.backlogProcessDelay, filter)

    dispatcher.pipe(backlogFiller)
    backlogFiller.pipe(filter)
    backlogFiller.pipe(backlogProcessor)

    validUserGate = new Gate((event) -> JSON.parse(event).isValidUser)
    backlogProcessor.pipe(validUserGate)

    invalidUserGate = new Gate((event) -> !JSON.parse(event).isValidUser)
    backlogProcessor.pipe(invalidUserGate)

    @redisWriter = new RedisWriter(redis_builder('filtered'))
    validUserGate.pipe(@redisWriter)
    validUserLogWriter = new LogWriter(config.logfile.valid_user_events)
    validUserGate.pipe(validUserLogWriter)

    invalidUserLogWriter = new LogWriter(config.logfile.invalid_user_events)
    invalidUserGate.pipe(invalidUserLogWriter)

    necessaryClosedStreams = 3
    closedStreams = 0
    closeStream = ->
      closedStreams++
      done() if closedStreams == necessaryClosedStreams

    @redisWriter.on 'close', closeStream
    validUserLogWriter.on 'close', closeStream
    invalidUserLogWriter.on 'close', closeStream

    distilleryRedis = redis_builder('distillery')
    queueEvent = (event, cb) ->
      distilleryRedis.lpush dispatcher.key, JSON.stringify(event), cb

    async.forEachSeries sourceEvents, queueEvent, ->
      process.nextTick dispatcher.destroy

  it 'works', (done) ->
    done()

  it 'writes the correct events to the valid user events message queue', (done) ->
    redis = redis_builder('filtered')

    redis.lrange @redisWriter.key, 0, -1, (err, reply) ->
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
