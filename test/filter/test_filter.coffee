Filter = require('../../lib/filter')
redisBuilder = require('../../lib/redis_builder')
should = require('should')
async = require("async")
sinon = require("sinon")

describe 'Filter', =>
  beforeEach (done) =>
    @filter = new Filter()
    @filter.init =>
      redisBuilder process.env.NODE_ENV, 'internal', (err, client) =>
        @redis = client
        @redis.flushdb done

  describe 'when a user logs in', =>
    it 'marks them as validated', (done) =>
      @sampleLogin = JSON.parse('{"eventName":"login", "userId":"George", "timestamp":86400}')
      @filter.processValidation @sampleLogin, (err0) =>
        @filter.checkValidation @sampleLogin.userId, (err, isValid) =>
          isValid.should.be.true
          done()

  describe 'when a user logs in with guid change', =>
    it 'marks both old and new user id as validated', (done) =>
      @sampleLogin = JSON.parse('{"eventName":"loginGuidChange", "userId":"George", "oldGuid":"Binky", "newGuid":"superNew", "timestamp":86400}')
      @filter.processValidation @sampleLogin, (err0) =>
        async.parallel [
          @filter.checkValidation.bind(@filter,@sampleLogin.userId)
          @filter.checkValidation.bind(@filter,@sampleLogin.oldGuid)
          @filter.checkValidation.bind(@filter,@sampleLogin.newGuid)
        ], (err, results) =>
          results[0].should.be.true
          results[1].should.be.true
          results[2].should.be.true
          done()

  describe 'when a user shows javascript capability', =>
    it 'marks them as validated', (done) =>
      @sampleLogin = JSON.parse('{"eventName":"jsCharacteristics", "userId":"George", "timestamp":86400}')
      @filter.processValidation @sampleLogin, (err0) =>
        @filter.checkValidation @sampleLogin.userId, (err, isValid) =>
          isValid.should.be.true
          done()

  describe 'when a user takes an action from an iOS app', =>
    it 'marks them as validated', (done) =>
      @sampleLogin = JSON.parse('{"eventName":"monkeyPath", "userId":"George", "timestamp":86400, "client":"iPad app"}')
      @filter.processValidation @sampleLogin, (err0) =>
        @filter.checkValidation @sampleLogin.userId, (err, isValid) =>
          isValid.should.be.true
          done()

  describe 'when a message is dispatched', =>
    it 'puts it in the holding/backlog', (done) =>
      sampleMessage = '{"eventName":"monkeyTime", "userId":"George", "timestamp":86400}'
      @filter.dispatchMessage sampleMessage, =>
        @redis.zcard @filter.holding_zstore_key, (err, result) =>
          result.should.equal 1
          done(err)

    it 'passes it to the user approval/classifier', (done) =>
      sampleMessage = '{"eventName":"monkeyTime", "userId":"George", "timestamp":86400}'
      spy = sinon.spy @filter, "processValidation"
      @filter.dispatchMessage sampleMessage, =>
        spy.calledOnce.should.be.true
        spy.getCall(0).args[0].should.eql(JSON.parse(sampleMessage))
        spy.restore()
        done()

    it 'triggers the backlog processor after passing the message to the user approval/classifier', (done) =>
      # Note: the ordering test seems like it could be flaky in detecting failure
      #   but in practice it does appear to reliably detect if they are called in the wrong order -- TL
      sampleMessage = '{"eventName":"monkeyTime", "userId":"George", "timestamp":86400}'
      @called_first = false
      stub = sinon.stub @filter, "processValidation", (msg, cb) =>
        @called_first = true
        # startTime = new Date().getTime();
        # while (new Date().getTime() < startTime + 500)
        #   null
        cb()
      spy = sinon.stub @filter, "processFromHolding", (ts, cb) =>
        @called_first.should.be.true
        cb()
      @filter.dispatchMessage sampleMessage, =>
        spy.calledOnce.should.be.true
        spy.getCall(0).args[0].should.eql(JSON.parse(sampleMessage).timestamp)
        spy.restore()
        stub.restore()
        done()
