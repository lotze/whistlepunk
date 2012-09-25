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
          fs.readFile @testFileDestination, (err, data) =>
            should.not.exist err

            # Fascinating:
            # console.log 'File reads: ' + data
            # data.should.eql messageObj.message
            #
            # Fails because data is '<Buffer 48 65 6c 6c 6f 20 77 6f 72 6c 64 48 65 6c 6c 6f 20 77 6f 72 6c 64 48 65 6c 6c 6f 20 77 6f 72 6c 64 48 65 6c 6c 6f 20 77 6f 72 6c 64 48 65 6c 6c 6f 20 77 ...>'
            # Yet logging it out appears normally

            console.log 'reading file'

            data.toString().should.eql JSON.stringify(@event) + '\n'

            done()

        upstream = new Stream()
        upstream.readable = true
        upstream.pipe @logWriter
        upstream.emit 'data', JSON.stringify @event