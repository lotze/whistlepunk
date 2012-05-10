var util = require('util'),
    Expeditor = require('./expeditor.js').Expeditor,
    EventEmitter = require('events').EventEmitter,
    zmq = require('zmq');

var Foreman = function() {
  EventEmitter.call(this);
  // this.eventStream = new JSONLogger("eventStream.log");
  // this.on('message', this.processStream.bind(this));
  var self = this;
  this.subscribeSocket = zmq.socket('sub');
  this.subscribeSocket.identity = 'metricizer';
  
  this.subscribeSocket.on('message', this.processStream.bind(this));
  process.on('SIGKILL', function(){
    self.subscribeSocket.close();
  });
};

util.inherits(Foreman, EventEmitter);

Foreman.prototype.setBoundListeners = function(objectToBindTo) {
  for (var i = 1; i < arguments.length; ++i) {
    var eventName = arguments[i][0];
    var functionName = arguments[i][1];
    this.on(eventName, objectToBindTo[functionName].bind(objectToBindTo));
  }
};

Foreman.prototype.writeStreamDataToMongo = function(streamData) {
  this.collection.insert(streamData);
};

Foreman.prototype.init = function(callback) {
  var self = this;
  
  // normally this should not be called until the db connection has been initialized
  callback();
};

Foreman.prototype.terminate = function() {
  this.studyHallSink.close();
  studyHallBackChannel.connection.close();
  this.db.close();
};

Foreman.prototype.processStream = function(message) {
  var streamData = JSON.parse(message);
  this.emit(streamData.eventName, streamData); // the workers will listen to these events here
  console.log(streamData.eventName, streamData);
  // this.log(streamData); // this was where we stored the canonical source for the event stream to file
  // this.writeStreamDataToMongo(streamData); // replicate the entire stream to a mongo collection
};

Foreman.prototype.log = function(streamData) {
  // this.eventStream.info(streamData);
};

Foreman.prototype.timestamp = function() {
  return new Date().getTime();
};

Foreman.prototype.formattedTimestamp = function(mSecTimestamp) {
  return new Date(mSecTimestamp).toUTCString();
};

var foreman = new Foreman();

module.exports = foreman;
