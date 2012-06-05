var util = require('util'),
    EventEmitter = require('events').EventEmitter,
    redis = require('redis'),
    config = require('../config'),
    Db = require('mongodb').Db,
    Connection = require('mongodb').Connection,
    Server = require('mongodb').Server;

var Foreman = function() {
  EventEmitter.call(this);
};

util.inherits(Foreman, EventEmitter);

Foreman.prototype.init = function(callback) {
  this.redis_key = "distillery:" + process.env.NODE_ENV + ":msg_queue";
  this.mongo = new Db(config.mongo_db_name, new Server(config.mongo_db_server, config.mongo_db_port, {}), {});
  callback();
};

Foreman.prototype.connect = function(callback) {
  this.connectRedis();
  this.startProcessing();
};

Foreman.prototype.connectRedis = function() {
  this.redis_client = redis.createClient(config.msg_source_redis.port, config.msg_source_redis.host);
  if (config.msg_source_redis.redis_db_num) {
    this.redis_client.select(config.msg_source_redis.redis_db_num);
  }
  console.log("Redis connected.");
  
  this.redis_client.once('end', function() {
    console.log("Lost connection to Redis. Reconnecting...");
    this.connectRedis();
  }.bind(this));  
};

Foreman.prototype.terminate = function() {
};

Foreman.prototype.startProcessing = function() {
  this.redis_client.brpop(this.redis_key, 0, function(err, reply) {
    if (err !== null && err !== undefined) {
      console.error("Error during Redis BRPOP: " + err);
      this.startProcessing();
    } else {
      var list = reply[0];
      var message = reply[1];
      this.handleMessage(message);      
    }
  }.bind(this));
};

Foreman.prototype.handleMessage = function(json_msg) {
  try {
    this.processMessage(JSON.parse(json_msg));
  } catch (err) {
    console.log("Error processing message:" + json_msg + "; error was " + err);
  } finally {
    this.startProcessing();
  }
};

Foreman.prototype.processMessage = function(message) {
  this.emit(message.eventName, message); // the workers will listen to these events here
  if (process.env.NODE_ENV == 'development') {
    console.log(message.eventName, message);
  }
};

var foreman = new Foreman();

module.exports = foreman;
