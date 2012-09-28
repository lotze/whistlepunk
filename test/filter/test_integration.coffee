process.env.NODE_ENV ?= 'test'

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

events = [
  { eventName: 'request', userId: users(0), timestamp: time() }
  { eventName: 'request', userId: users(0), timestamp: time(seconds: 30) }
  { eventName: 'jsCharacteristics', userId: users(1), jsEnabled: true, timestamp: time(minutes: 1) }
  { eventName: 'request', userId: users(2), client: 'iPad app', timestamp: time(minutes: 2) }
  { eventName: 'request', userId: users(3), client: 'iPhone app', timestamp: time(minutes: 3) }
  { eventName: 'request', userId: users(4), timestamp: time(minutes: 4) }
  { eventName: 'login', userId: users(4), timestamp: time(minutes: 4, seconds: 5) }
]

describe "Filter integration", ->
  beforeEach (done) ->
    flushRedis = (redis, cb) ->
      redis.flushdb ->
        redis.quit cb

    redises = [redis_builder('distillery'), redis_builder('whistlepunk'), redis_builder('filtered')]
    async.forEach redises, flushRedis, done

  beforeEach (done) ->
    userValidators    = [JavaScriptEnabledValidator, LoginValidator, IosClientValidator]

    dispatcher        = new Dispatcher(redis_builder('distillery'))
    backlogFiller     = new BacklogFiller(redis_builder('whistlepunk'))
    filter            = new Filter(redis_builder('whistlepunk'), userValidators, config.expirations.filterBackwardExpireDelay)
    backlogProcessor  = new BacklogProcessor(redis_builder('whistlepunk'), config.expirations.backlogProcessDelay, filter)

    dispatcher.pipe(backlogFiller)
    dispatcher.pipe(filter)
    dispatcher.pipe(backlogProcessor)

    validUserGate = new Gate((event) -> JSON.parse(event).isValidUser)
    backlogProcessor.pipe(validUserGate)

    invalidUserGate = new Gate((event) -> !JSON.parse(event).isValidUser)
    backlogProcessor.pipe(invalidUserGate)

    redisWriter = new RedisWriter(redis_builder('filtered'))
    validUserGate.pipe(redisWriter)
    validUserLogWriter = new LogWriter(config.logfile.valid_user_events)
    validUserGate.pipe(validUserLogWriter)

    invalidUserLogWriter = new LogWriter(config.logfile.valid_user_events)
    invalidUserGate.pipe(invalidUserLogWriter)

    necessaryClosedStreams = 3
    closedStreams = 0
    closeStream = ->
      closedStreams++
      done() if closedStreams == necessaryClosedStreams

    redisWriter.on 'close', closeStream
    validUserLogWriter.on 'close', closeStream
    invalidUserLogWriter.on 'close', closeStream

    distilleryRedis = redis_builder('distillery')
    queueEvent = (event, cb) ->
      distilleryRedis.lpush dispatcher.key, JSON.stringify(event), cb

    async.forEachSeries events, queueEvent, ->
      setTimeout (->dispatcher.destroy()), 1000

  it 'works', (done) ->
    done()
