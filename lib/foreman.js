var util = require('util'),
    EventEmitter = require('events').EventEmitter,
    zmq = require('zmq');

var Foreman = function() {
  EventEmitter.call(this);
};

util.inherits(Foreman, EventEmitter);

Foreman.prototype.init = function(callback) {
  callback();
};

Foreman.prototype.connect = function(pullLocation) {
  this.subscribeSocket = zmq.socket('sub');
  this.subscribeSocket.identity = 'metricizer';
  this.subscribeSocket.on('message', this.processStream.bind(this));
  this.subscribeSocket.connect(pullLocation);
  this.subscribeSocket.subscribe('');
};

Foreman.prototype.terminate = function() {
  self.subscribeSocket.close();
};

Foreman.prototype.processStream = function(message) {
  var streamData = JSON.parse(message);
  this.emit(streamData.eventName, streamData); // the workers will listen to these events here
  console.log(streamData.eventName, streamData);
};

var foreman = new Foreman();

module.exports = foreman;
