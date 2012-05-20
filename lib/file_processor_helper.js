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

FileProcessorHelper.prototype.processLine = function(line) {
  var json_data = JSON.parse(line);
  this.emit(json_data.eventName, json_data);
};

FileProcessorHelper.prototype.getLogFilesInOrder = function(directory) {
  if (process.env.NODE_ENV == 'development')
    return(["shares.log","sessions.log"])
  return(["learnist.log.old","learnist.log.1.learnist.20120414_203806", "learnist.log.1.learnist.20120417_000201", "learnist.log.1.learnist.20120417_235902", "learnist.log.1.learnist.20120418_235901", "learnist.log.1.learnist.20120419_235901", "learnist.log.1.learnist.20120420_235902", "learnist.log.1.learnist.20120421_235901", "learnist.log.1.learnist.20120422_235901", "learnist.log.1.learnist.20120423_235901", "learnist.log.1.learnist.20120424_235901", "learnist.log.1.learnist.20120425_235901", "learnist.log.1.learnist.20120426_235901", "learnist.log.1.learnist.20120427_235901", "learnist.log.1.learnist.20120428_235901", "learnist.log.1.learnist.20120429_235901", "learnist.log.1.learnist.20120430_235901", "learnist.log.1.learnist.20120501_235901", "learnist.log.1.learnist.20120502_235901", "learnist.log.1.learnist.20120503_235902", "learnist.log.1.learnist.20120504_235901", "learnist.log.1.learnist.20120505_235901", "learnist.log.1.learnist.20120506_235901", "learnist.log.1.learnist.20120507_235901", "learnist.log.1.learnist.20120508_235901", "learnist.log.1.learnist.20120509_235901", "learnist.log.1.learnist.20120510_235901", "learnist.log.1.learnist.20120511_235901", "learnist.log.1.learnist.20120512_235901", "learnist.log.1.learnist.20120513_235901", "learnist.log.1.learnist.20120514_235901", "learnist.log.1.learnist.20120515_235901", "learnist.log.1.learnist.20120516_235901", "learnist.log.1.learnist.20120517_235901", "learnist.log.1.learnist.20120518_235901", "learnist.log.1.learnist.20120519_235902", "learnist.log"])
    // var fs = require("fs");
    // fs.readdir(directory, function(err1, files) {
    //   function sep(element, index, array) {
    //       if( fs.statSync( path.join(filename + element) ).isDirectory() ){
    //           dirs_in.push(element);
    //       } else {
    //           files_in.push(element);
    //       }
    //   }
    //   files.forEach(is);
    //   dirs_in.sort().forEach(printBr);
    //   callback(err1, )
    // });
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
  
FileProcessorHelper.prototype.processFileForForeman = function(file, foreman, lastEvent, callback) {
    var fs = require("fs");
    var self = this;
    async.forEachSeries(fs.readFileSync(file).toString().split('\n'), function(line, line_cb) {
      var matches = line.toString().match(/^[^\{]*(\{.*\})/);
      if ((matches != null) && (matches.length > 0)) {
        var jsonString = matches[1]
        var streamData = JSON.parse(jsonString);
        if (streamData.timestamp <= lastEvent.timestamp) {
          // emit event with the eventName like foreman would
          //console.log("event line " + jsonString + " is older than " + lastEvent.timestamp + " -- processing")
          foreman.emit(streamData.eventName, streamData);        
        // } else {
        //   console.log("event line " + jsonString + " is newer than " + lastEvent.timestamp + " -- skipping")
        }
      } else {
        console.log("event line " + jsonString + " had a parsing issue -- SKIPPING")
      }
      line_cb(null);
    }, function(err) {
      callback(err);
    });
  };
  
FileProcessorHelper.prototype.clearDatabase = function(callback) {
    async.parallel([
      function(parallel_callback) {this.db.query("TRUNCATE TABLE olap_users").execute(parallel_callback);},
      function(parallel_callback) {this.db.query("TRUNCATE TABLE sources_users").execute(parallel_callback);},
      function(parallel_callback) {this.db.query("TRUNCATE TABLE users_created_at").execute(parallel_callback);},
      function(parallel_callback) {this.db.query("TRUNCATE TABLE users_membership_status_at").execute(parallel_callback);},
      function(parallel_callback) {this.db.query("TRUNCATE TABLE all_measurements").execute(parallel_callback);},
      function(parallel_callback) {this.db.query("TRUNCATE TABLE all_objects").execute(parallel_callback);},
      function(parallel_callback) {this.db.query("TRUNCATE TABLE summarized_metrics").execute(parallel_callback);},
      function(parallel_callback) {this.db.query("TRUNCATE TABLE timeseries").execute(parallel_callback);},
      function(parallel_callback) {this.db.query("TRUNCATE TABLE shares").execute(parallel_callback);},
      function(parallel_callback) {this.db.query("TRUNCATE TABLE in_from_shares").execute(parallel_callback);},
    ],
    // optional callback
    function(err, results){
        callback(err, results);
    });
  };

module.exports = FileProcessorHelper