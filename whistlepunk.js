#!/usr/bin/env node

if (process.env.NODE_ENV === null || process.env.NODE_ENV === undefined)
  process.env.NODE_ENV = 'development'

require('coffee-script')

var run = function(callback) {
  var fs = require('fs'),
      zmq = require('zmq'),
      config = require('./config'),
      async = require('async'),
      foreman = require('./lib/foreman.js');
    
  var workers = {};
  var lib = {};
  var tasks = [];

  foreman.init(function(err) {
    files = fs.readdirSync('./workers')
    
    async.forEach(files, function(workerFile, worker_callback) {
      var workerName = workerFile.replace('.js', '');
      tasks.push(workerName);
      WorkerClass = require('./workers/'+workerFile);
      workers[workerName] = new WorkerClass(foreman);
      workers[workerName].init(worker_callback);      
    }, function(err) {
      if (err !== null && err !== undefined) { throw err; }

      var pullLocation = "tcp://" + config.zmq.host + ":" + config.zmq.port;
      console.log("WhistlePunk: connecting foreman to " + pullLocation);
      foreman.connect(pullLocation);
      console.log('WhistlePunk: running...');
      if(callback) {
        callback();
      }
    });
  });
};

if(require.main === module) {
  console.log("Initializing WhistlePunk");
  run();
}

exports.run = run;

var terminate = exports.terminate = function() {
  foreman.terminate();
};

process.on('SIGKILL', function() {
  terminate();
});

process.on('SIGINT', function() {
  terminate();
});
