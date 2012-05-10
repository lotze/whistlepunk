var foreman = require('./lib/foreman.js');

var run = function(callback) {

  var fs = require('fs'),
      Expeditor = require('./lib/expeditor.js').Expeditor,
      zmq = require('zmq'),
      foreman = require('./lib/foreman.js');
    
  var workers = {};
  var lib = {};
  var ex = new Expeditor();
  var tasks = [];

  foreman.init(function(err) {
  
    fs.readdirSync('./workers').forEach(function(file) {
      var workerName = file.replace('.js', '');
      tasks.push(workerName);
      WorkerClass = require('./workers/'+file);
      workers[workerName] = new WorkerClass(foreman);
      workers[workerName].init(ex(workerName));
    });

    ex(tasks, function() {
      var pullLocation = 'tcp://127.0.0.1:9000';
      foreman.subscribeSocket.connect(pullLocation);
      foreman.subscribeSocket.subscribe('');
      console.log("connecting to " + pullLocation + "...");
      console.log('WhistlePunk: running...');
      if(callback){
        callback();
      }
    });
  });
};

//if(!process.argv[2] || process.argv[2].indexOf("spec") == -1) {
//  run();
//}
if(require.main === module) {
  run();
}

exports.run = run;

var terminate = exports.terminate = function() {
  foreman.terminate();
};

process.on('SIGKILL', function() {
  terminate();
});
