var zmq = require('zmq')

// socket to talk to server
var requester = zmq.socket('sub');
requester.identity = 'metricizer';

var Foreman = require('./lib/foreman');
foreman = new Foreman();

requester.on("message", function(message) {
  console.log("Received message: ", message.toString(), '');
  foreman.processStream(message);
});

requester.connect("tcp://127.0.0.1:9000");
requester.subscribe('');

process.on('SIGINT', function() {
  requester.close();
});