should = require("should")
assert = require("assert")
FileProcessorHelper = require("../lib/file_processor_helper")
fileProcessorHelper = new FileProcessorHelper()

describe "a file processor helper", ->
  describe "when returning a list of log files", ->
    it "should return all files in the directory matching, plus learnist.log.old and learnist.log", (done) ->
      fileProcessorHelper.getLogFilesInOrder "#{__dirname}/fixture_logs", (err, results) =>
        results.length.should.eql 4
        results[0].should.eql "learnist.log.old"
        results[1].should.eql "learnist.log.1.learnist.20010101_000000"
        results[2].should.eql "learnist.log.1.learnist.20120414_203806"
        results[3].should.eql "learnist.log"
        done(err)