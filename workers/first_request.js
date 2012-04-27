var util = require('util'),
    EventEmitter = require('events').EventEmitter,
    foreman = require('../lib/foreman.js');

var FirstRequest = function() {
  EventEmitter.call(this);
  foreman.on('firstRequest', this.handleFirstRequest.bind(this));
};

Persistence.prototype.init = function(callback) {
  // generally here we need to make sure db connections are openned properly before executing the callback
  callback();
  
};

FirstRequest.prototype.handleFirstRequest = function(json) {
  console.log("Here is the data for FirstRequest:", json)
};

util.inherits(FirstRequest, EventEmitter);