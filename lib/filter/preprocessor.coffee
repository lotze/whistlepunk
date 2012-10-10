{EventEmitter} = require 'events'
{future, join} = require 'futures'
config = require '../../config'
redis_builder = require '../../lib/redis_builder'

Dispatcher = require './dispatcher'
BacklogFiller = require './backlog_filler'
BacklogProcessor = require './backlog_processor'
Filter = require './filter'
ValidUserChecker = require './valid_user_checker'
RedisWriter = require './redis_writer'
LogWriter = require './log_writer'
Gate = require './gate'

JavaScriptEnabledValidator = require './validators/java_script_enabled_validator'
LoginValidator = require './validators/login_validator'
IosClientValidator = require './validators/ios_client_validator'
FullUserValidator = require './validators/full_user_validator'

class Preprocessor extends EventEmitter
  constructor: ->
    super()

    @userValidators    = [JavaScriptEnabledValidator, LoginValidator, IosClientValidator, FullUserValidator]

    @dispatcher        = new Dispatcher(redis_builder('distillery'))
    @backlogFiller     = new BacklogFiller(redis_builder('whistlepunk'))
    @filter            = new Filter(redis_builder('whistlepunk'), @userValidators, config.expirations.filterBackwardExpireDelay)
    @validUserChecker  = new ValidUserChecker(redis_builder('whistlepunk'))
    @backlogProcessor  = new BacklogProcessor(redis_builder('whistlepunk'), config.expirations.backlogProcessDelay, @filter, @validUserChecker)

    @dispatcher.pipe(@backlogFiller)
    @backlogFiller.pipe(@filter)
    @backlogFiller.pipe(@backlogProcessor)

    @validUserGate = new Gate((event) -> JSON.parse(event).isValidUser)
    @backlogProcessor.pipe(@validUserGate)

    @invalidUserGate = new Gate((event) -> !JSON.parse(event).isValidUser)
    @backlogProcessor.pipe(@invalidUserGate)

    @redisWriter = new RedisWriter(redis_builder('filtered'))
    @validUserGate.pipe(@redisWriter)
    @validUserLogWriter = new LogWriter(config.logfile.valid_user_events)
    @validUserGate.pipe(@validUserLogWriter)

    @invalidUserLogWriter = new LogWriter(config.logfile.invalid_user_events)
    @invalidUserGate.pipe(@invalidUserLogWriter)

    redisWriterClosePromise = future.create()
    validUserLogWriterPromise = future.create()
    invalidUserLogWriterPromise = future.create()
    combinedStreamClosePromise = join.create()
    combinedStreamClosePromise.add(redisWriterClosePromise, validUserLogWriterPromise, invalidUserLogWriterPromise)
    combinedStreamClosePromise.when =>
      @emit 'close'

    @redisWriter.on 'close', @onStreamClose.bind(this, redisWriterClosePromise)
    @validUserLogWriter.on 'close', @onStreamClose.bind(this, validUserLogWriterPromise)
    @invalidUserLogWriter.on 'close', @onStreamClose.bind(this, invalidUserLogWriterPromise)
    
    # ...this locks the preprocessor in a state that needs to be killed :(
    #@backlogFiller.on 'error', @destroy

  destroy: =>
    console.log("preprocessor trying to destroy dispatcher")
    @dispatcher.destroy()

  onStreamClose: (promise) =>
    promise.deliver()

module.exports = Preprocessor
