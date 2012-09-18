Preprocessor = require('../../lib/preprocessor')
redisBuilder = require('../../lib/redis_builder')
should = require('should')
assert = require('assert')
async = require("async")
sinon = require("sinon")
config = require("../../config")

describe 'Preprocessor', =>
  before (done) =>
    @preprocessor = Preprocessor
    @preprocessor.init(done)

  describe 'when there is data in the redis queue', =>
    it 'should call @processMessage', (done) =>
      sampleMessage = '{"eventName":"monkeyTime", "userId":"George", "timestamp":86400}'
      
      distillery_redis_key = "distillery:" + process.env.NODE_ENV + ":msg_queue"
      redisBuilder process.env.NODE_ENV, 'distillery', (err, client) =>
        distillery_redis_client = client

        stub = sinon.stub @preprocessor, "processMessage", =>
          console.log "HERE WE ARE MOM"
          spy = @preprocessor.processMessage
          spy.calledOnce.should.be.true
          spy.getCall(0).args[0].should.eql(sampleMessage)
          spy.restore()
          done()

        @preprocessor.startProcessing()
        distillery_redis_client.lpush(distillery_redis_key, sampleMessage)
