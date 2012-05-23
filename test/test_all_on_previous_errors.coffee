should = require("should")
assert = require("assert")
async = require("async")
fs = require('fs')
FileProcessorHelper = require("../lib/file_processor_helper")
fileProcessorHelper = new FileProcessorHelper()

describe "the set of all workers", ->
  before (done) =>
    files = fs.readdirSync('./workers')
    workers = {}
    async.forEach files, (workerFile, worker_callback) =>
      workerName = workerFile.replace('.js', '')
      WorkerClass = require('../workers/'+workerFile)
      worker = new WorkerClass(fileProcessorHelper)
      workers[workerName] = worker
      workers[workerName].init(worker_callback)
    , (err) =>
      done()
      
  describe "when processing an entry with a single quote", ->
    it "should not have an error", ->
      mustBeValidString = '{"service":"learnist","timestamp":1331851773.29056,"formattedTime":"2012-03-15 22:49:33 +0000","xhr":null,"userId":"joe","eventName":"request","ip":"24.5.83.80","requestUri":"/it\'s-a-me-mario","referrer":"http://monkey.com/why\'d-we-do-that","userAgent":"Safari","fromShare":null}'
      fileProcessorHelper.processLine(mustBeValidString)
  
  describe "when processing an entry with a null highlightedLearningId", ->
    it "should not have an error", ->
      mustBeValidString = '{"service":"learnist","timestamp":1337387939.021151,"formattedTime":"2012-05-19 00:38:59 +0000","releaseRevision":"d2a440a8d63abe4cd66fe889f6d0cfcd88f4973c","userId":"7e7adc80-8373-012f-8d73-1adb9a793d61","eventName":"viewedBoard","boardId":1291,"highlightedLearningId":null}'
      fileProcessorHelper.processLine(mustBeValidString)
      
  describe "when processing a tag created entry", ->
    it "should not have an error", ->
      mustBeValidString = '{"service":"learnist","timestamp":1337492142.625129,"formattedTime":"2012-05-20 05:35:42 +0000","releaseRevision":"d2a440a8d63abe4cd66fe889f6d0cfcd88f4973c","userId":"1664ce40-7f8f-012f-c420-1adb9a793d61","eventName":"createdTag","taggableType":"Learning","taggableId":11210,"tagName":"photography"}'
      fileProcessorHelper.processLine(mustBeValidString)
      
  describe "when processing a firstRequest with a null referrer", ->
    it "should not have an error", ->
      mustBeValidString = '{"service":"learnist","timestamp":1329933607.612448,"formattedTime":"2012-02-22 18:00:07 +0000","userId":"fa90dbe0-3fac-012f-5b2e-12313d2bb138","eventName":"firstRequest","ip":"206.169.112.34","requestUri":"/","referrer":null,"userAgent":"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_6_8) AppleWebKit/535.11 (KHTML, like Gecko) Chrome/17.0.963.56 Safari/535.11"}'
      fileProcessorHelper.processLine(mustBeValidString)
