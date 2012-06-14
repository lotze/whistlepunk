Foreman = require('../lib/foreman')
Redis = require('../lib/redis')
should = require('should')
assert = require('assert')
sinon = require("sinon")
fs = require("fs")
async = require("async")

describe 'Foreman', =>
  before (done) =>
    @foreman = new Foreman()
    Redis.getClient (err, client) =>
      return done(err) if err?
      @client = client
      @foreman.init done
    
  describe '#handleMessage', =>
    it 'should call processMessage', (done) =>
      sampleMessage = '{"eventName":"monkeyTime", "userId":"George", "timestamp":86400}'
      stub = sinon.stub @foreman, "startProcessing", =>
        done()
      spy = sinon.spy @foreman, "processMessage"
      @foreman.handleMessage(sampleMessage)
      spy.calledOnce.should.be.true
      spy.getCall(0).args[0].should.eql(JSON.parse(sampleMessage))
      @foreman.startProcessing.restore()
      @foreman.processMessage.restore()
      
    it 'should start listening on the redis msg queue again afterwards', (done) =>
      sampleMessage = '{"eventName":"monkeyTime", "userId":"George", "timestamp":86400}'
      stub = sinon.stub @foreman, "startProcessing", =>
        done()
      @foreman.handleMessage(sampleMessage)
      stub.calledOnce.should.be.true
      @foreman.startProcessing.restore()

  describe '#processMessage', =>
    it 'should emit an event with the message event', (done) =>
      exampleMessage = {eventName: "crazyEventTest", timestamp: 1010101}
      @foreman.on exampleMessage.eventName, (eventToProcess) =>
        eventToProcess.should.equal(exampleMessage)
        done(null)
      @foreman.processMessage(exampleMessage)
    describe "when successful", =>
      it "should store the message in the last processed redis entry", (done) =>
        exampleMessage = {eventName: "timingIsEverything", timestamp: 1123}
        @foreman.processMessage(exampleMessage)
        @client.get "whistlepunk:last_event_processed", (err, result) =>
          return done(err) if err?
          result.should.equal(JSON.stringify(exampleMessage))
          done()
    describe "when NOT successful", =>
      it "should NOT store the message in the last processed redis entry"

  describe '#addAllWorkers', =>
    it 'should instantiate and attach all workers in the workers directory'

  describe "#getLogFilesInOrder", =>
    it "should return all files in the directory or subdirectories matching the pattern", (done) =>
      @foreman.getLogFilesInOrder "#{__dirname}/fixture_logs", (err, results) =>
        results.length.should.eql 3
        async.parallel [
          (cb) => fs.realpath results[0], (err, fullpath) =>
            fullpath.should.eql "#{__dirname}/fixture_logs/learnist.log.1.some_other_machine.19990101_000000"
            cb(err, fullpath)
          (cb) => fs.realpath results[1], (err, fullpath) =>
            fullpath.should.eql "#{__dirname}/fixture_logs/subdir/learnist.log.1.learnist.20010101_000000"
            cb(err, fullpath)
          (cb) => fs.realpath results[2], (err, fullpath) =>
            fullpath.should.eql "#{__dirname}/fixture_logs/learnist.log.1.learnist.20120414_203806"
            cb(err, fullpath)
        ], done
        
  describe '#processFiles', (done) =>
    it 'should process all files in the log directory, in order', (done) =>
      start = {timestamp: 1}
      end = {timestamp: 2}
      @foreman.getLogFilesInOrder "#{__dirname}/fixture_logs", (err, logFilesInOrder) =>
        stub = sinon.stub @foreman, "processFile", (filename, s, e, callback) =>
          filename.should.eql(logFilesInOrder.shift())
          s.should.eql(start)
          e.should.eql(end)
          callback()
        @foreman.processFiles "#{__dirname}/fixture_logs", start, end, (err, results) =>
          return done(err) if err?
          @foreman.processFile.restore()
          done()

  describe '#processFile', =>
    it 'should process all events from the file, EXCEPT events up to and including any provided start event AND events after any provided final event', (done) =>
      start = {eventName: 'startEvent', timestamp: 915364800}
      end = {eventName: 'startEvent', timestamp: 922968000}

      spy = sinon.spy @foreman, "processMessage"
      @foreman.processFile "#{__dirname}/log/board_creation.json", start, end, (err, results) =>
        return done(err) if err?
        @foreman.callbackWhenClear =>
          spy.callCount.should.eql(5)
          for callNum in [0..(spy.callCount-1)]
            spy.getCall(callNum).args[0].timestamp.should.be.above(start.timestamp)
            spy.getCall(callNum).args[0].timestamp.should.not.be.above(end.timestamp)
          @foreman.processMessage.restore()
          done()