Stream = require 'stream'
LogWriter = require '../../lib/filter/log_writer'
should = require 'should'
fs = require 'fs'

describe 'LogWriter', ->
  beforeEach () ->
    @testFileDestination = "/tmp/test_log_writer.txt"
    # @messageObj = {}
    # @messageObj.message = "Hello world"
    @logWriter = new LogWriter @testFileDestination
    @event = {"name": "event", "timestamp": 1348186752000, "userId": "123"}

  describe "#write", ->

    it "should append piped data to a log file", (done) ->

      # Clear out file from previous appends
      fs.writeFile @testFileDestination, '', (err) =>

        @logWriter.on 'doneProcessing', =>
          fs.readFile @testFileDestination, 'utf8', (err, data) =>
            should.not.exist err
            data.should.eql JSON.stringify(@event) + '\n'
            done()

        upstream = new Stream()
        upstream.readable = true
        upstream.pipe @logWriter
        upstream.emit 'data', JSON.stringify @event