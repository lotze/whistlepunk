var foreman = require('./lib/foreman.js');

var run = function(callback) {

  var fs = require('fs'),
      Expeditor = require('./lib/expeditor').Expeditor;
    
  var workers = {};
  var lib = {};
  var ex = new Expeditor();
  var tasks = [];

  foreman.init(function(err) {
  
    fs.readdirSync('./workers').forEach(function(file) {
      var workerName = file.replace('.js', '');
      tasks.push(workerName);
      workers[workerName] = require('./workers/'+file);
      workers[workerName].init(ex(workerName));
    });

    ex(tasks, function() {
        console.log('WhistlePunk: running...');
        if(callback){
          callback();
        }
      // });
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
