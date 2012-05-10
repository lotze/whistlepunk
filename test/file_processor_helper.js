var async = require('async');
var EventEmitter = require('events').EventEmitter;
var util = require('util');

var FileProcessorHelper = function () {
  EventEmitter.call(this);
  this.jsonFinderRegEx = new RegExp(/^[^\{]*(\{.*\})/);
  var DbLoader = require('../lib/db_loader.js');
  var dbloader = new DbLoader();
  this.db = dbloader.db();  
}

util.inherits(FileProcessorHelper, EventEmitter);

FileProcessorHelper.prototype.db = function() {
    return this.db;
  };
  
FileProcessorHelper.prototype.processFile = function(file) {
    var lazy = require("lazy"),
    fs = require("fs");
    var self = this;

    new lazy(fs.createReadStream(file))
      .lines
      .forEach(function(line){
        // doesn't work??
        //var matches = line.toString().match(this.jsonFinderRegEx);
        var matches = line.toString().match(/^[^\{]*(\{.*\})/);
        var jsonString = matches[1]
        var streamData = JSON.parse(jsonString);
        // emit event with the eventName like foreman would
        self.emit(streamData.eventName, streamData);
       }
     );
  };
  
FileProcessorHelper.prototype.clearDatabase = function(callback) {
    async.parallel([
      function(parallel_callback) {this.db.query("TRUNCATE TABLE olap_users").execute(function(error, rows, cols) {}); parallel_callback(null,null);},
      function(parallel_callback) {this.db.query("TRUNCATE TABLE sources_users").execute(function(error, rows, cols) {}); parallel_callback(null,null);},
      function(parallel_callback) {this.db.query("TRUNCATE TABLE users_created_at").execute(function(error, rows, cols) {}); parallel_callback(null,null);},
      function(parallel_callback) {this.db.query("TRUNCATE TABLE users_membership_status_at").execute(function(error, rows, cols) {}); parallel_callback(null,null);},
      function(parallel_callback) {this.db.query("TRUNCATE TABLE all_measurements").execute(function(error, rows, cols) {}); parallel_callback(null,null);},
      function(parallel_callback) {this.db.query("TRUNCATE TABLE all_objects").execute(function(error, rows, cols) {}); parallel_callback(null,null);},
      function(parallel_callback) {this.db.query("TRUNCATE TABLE summarized_metrics").execute(function(error, rows, cols) {}); parallel_callback(null,null);},
      function(parallel_callback) {this.db.query("TRUNCATE TABLE timeseries").execute(function(error, rows, cols) {}); parallel_callback(null,null);},
      function(parallel_callback) {this.db.query("TRUNCATE TABLE shares").execute(function(error, rows, cols) {}); parallel_callback(null,null);},
      function(parallel_callback) {this.db.query("TRUNCATE TABLE in_from_shares").execute(function(error, rows, cols) {}); parallel_callback(null,null);},
    ],
    // optional callback
    function(err, results){
        // the results array will equal ['one','two'] even though
        // the second function had a shorter timeout.
        if(callback) {
          callback(err, results);
        }
    });
  };

module.exports = FileProcessorHelper