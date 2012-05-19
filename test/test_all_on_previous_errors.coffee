should = require("should")
assert = require("assert")
async = require("async")
fs = require('fs')
FileProcessorHelper = require("./file_processor_helper")
fileProcessorHelper = new FileProcessorHelper()

describe "the set of all workers", ->
  before (done) =>
    files = fs.readdirSync('./workers')
    workers = {}
    async.forEach files, (workerFile, worker_callback) =>
      workerName = workerFile.replace('.js', '')
      WorkerClass = require('../workers/'+workerFile)
      workers[workerName] = new WorkerClass(fileProcessorHelper)
      workers[workerName].init(worker_callback)
    , (err) =>
      done()
  
  describe "when processing an entry with a null highlightedLearningId", ->
    it "should not have an error", ->
      mustBeValidString = '{"service":"learnist","timestamp":1337387939.021151,"formattedTime":"2012-05-19 00:38:59 +0000","releaseRevision":"d2a440a8d63abe4cd66fe889f6d0cfcd88f4973c","userId":"7e7adc80-8373-012f-8d73-1adb9a793d61","eventName":"viewedBoard","boardId":1291,"highlightedLearningId":null}'
      fileProcessorHelper.processLine(mustBeValidString)