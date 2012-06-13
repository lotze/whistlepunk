Foreman = require('../lib/foreman')
should = require('should')
assert = require('assert')

describe 'Foreman', =>
  before (done) =>
    @foreman = new Foreman()
    @foreman.init done
    
  describe '#handleMessage', =>
    it 'should call processMessage'
    describe "when successful", =>
      it "should store the message's timestamp in the last processed redis entry"
    describe "when NOT successful", =>
      it "should NOT store the message's timestamp in the last processed redis entry"

  describe '#processMessage', =>
    it 'should emit an event with the message eventName'

  describe '#attachWorkers', =>
    it 'should instantiate and attach all workers in the workers directory'

  describe '#processLogsBetween', =>
    it 'should process all files in the log directory, only processing events between the provided events'