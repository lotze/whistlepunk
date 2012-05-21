#!/usr/bin/env node

if (process.env.NODE_ENV === null || process.env.NODE_ENV === undefined)
  process.env.NODE_ENV = 'development'

require('coffee-script');
var redis = require('redis');
var config = require('./config');
FileProcessorHelper = require('./lib/file_processor_helper');

process.on('uncaughtException', function(e) {
  console.error("UNCAUGHT EXCEPTION: ", e, e.stack);
});

var quit = function() {
  process.exit(0);
};

process.on('SIGINT', quit);
process.on('SIGKILL', quit);

var run = function(callback) {
  var fs = require('fs'),
      config = require('./config'),
      async = require('async'),
      foreman = require('./lib/foreman.js');
    
  var workers = {};
  var lib = {};

  var terminate = exports.terminate = function() {
    foreman.terminate();
  };

  process.on('SIGKILL', function() {
    terminate();
  });

  process.on('SIGINT', function() {
    terminate();
  });

  foreman.init(function(err) {
    files = fs.readdirSync('./workers')
    
    async.forEach(files, function(workerFile, worker_callback) {
      var workerName = workerFile.replace('.js', '');
      WorkerClass = require('./workers/'+workerFile);
      workers[workerName] = new WorkerClass(foreman);
      workers[workerName].init(worker_callback);      
    }, function(err) {
      if (err !== null && err !== undefined) { throw err; }
      
      if (process.env.REPROCESS === null || process.env.REPROCESS === undefined) {
        console.log("WhistlePunk: connecting foreman to remote redis");
        foreman.connect(function(err) {
          if (err !== null && err !== undefined) { throw err; }
          console.log('WhistlePunk: running...');
          if(callback) {
            callback();
          }
        });
      } else {
        var fileProcessorHelper = new FileProcessorHelper();
        async.series([
          // first delete all data
          function(cb) {
            console.log("WhistlePunk: deleting old data");
            fileProcessorHelper.clearDatabase (cb);
          }.bind(this),
          // then get the first event in the redis queue
          function(cb) {
            console.log("WhistlePunk: getting first redis event");
            redis_client = redis.createClient(config.msg_source_redis.port, config.msg_source_redis.host);
            redis_key = "distillery:" + process.env.NODE_ENV + ":msg_queue";
            redis_client.brpop(redis_key, 0, function(err, reply) {
              if (err !== null && err !== undefined) {
                console.error("Error during Redis BRPOP: " + err);
              } else {
                var list = reply[0];
                var message = reply[1];
                console.log("got list " + list + ", msg " + message);
                // then process all data from all log files up to that event
                finalMessage = JSON.parse(message);
                var logPath = "/opt/grockit/log/";
                if (process.env.NODE_ENV == 'development') {
                  logPath = "/Users/grockit/workspace/metricizer/spec/log/";
                }
                fileProcessorHelper.getLogFilesInOrder(logPath, function (err, fileList) {
                  if (err !== null && err !== undefined) {
                    return console.error("Error while getting log files: " + err);
                  }

                  console.log("Processing log file list: ", fileList);
                  async.forEachSeries(fileList, function(fileName, file_cb) {
                    console.log("WhistlePunk: processing old log: " + logPath + fileName);
                    fileProcessorHelper.processFileForForeman(logPath + fileName, foreman, finalMessage, file_cb);
                  }, function(err) {
                    cb(err);
                  });
                });
              }
            }.bind(this));
          }.bind(this),
          // then start whistlepunk
          function(cb) {
            console.log("WhistlePunk: connecting foreman to remote redis");
            foreman.connect(cb);
          }.bind(this)
        ], function(err, results) {
          if (err !== null && err !== undefined) { throw err; }
          console.log('WhistlePunk: running...');
          if(callback) {
            callback();
          }
        });
      }
    });
  });
};

if(require.main === module) {
  console.log("Initializing WhistlePunk");
  run();
}

exports.run = run;

