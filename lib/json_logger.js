var util = require('util'),
    StreamLogger = require('streamlogger').StreamLogger,
    ENV = require('./env');

var JSONLogger = function(logFile) {
  StreamLogger.call(this, ENV.setting('logPath')+logFile);

  this.format = function(message, levelName){
    message.timestamp = message.timestamp || new Date().getTime();
    return JSON.stringify(message);
  };

  process.addListener("SIGHUP", function() {
    this.reopen();
  }.bind(this));
};

util.inherits(JSONLogger, StreamLogger);

module.exports = JSONLogger;
