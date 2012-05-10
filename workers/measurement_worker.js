var MeasurementWorker = function (foreman) {
  this.foreman = foreman;
  var DbLoader = require('../lib/db_loader.js');
  var dbloader = new DbLoader();
  this.db = dbloader.db();
  this.foreman.on('measureMe', this.processEvent.bind(this));  
}

MeasurementWorker.prototype.init = function(callback) {
  // generally here we need to make sure db connections are openned properly before executing the callback
  callback();
};

MeasurementWorker.prototype.processEvent = function (logHash) {
  var actorId = logHash['actorId'] || logHash['userId'];
  var actorType = logHash['actorType'] || 'user';
  var measureName = logHash['measureName'];
  var measureTarget = logHash['targetId'] || logHash['measureTarget'] || '';
  var measureAmount = logHash['measureAmount'] || 1;
  var timestamp = logHash['timestamp'];
  this.db.query("INSERT INTO all_measurements (object_id, object_type, measure_name, measure_target, amount, first_time) VALUES ('" + this.db.escape(actorId) + "', '" + this.db.escape(actorType) + "', '" + this.db.escape(measureName) + "', '" + this.db.escape(measureTarget) + "', " + measureAmount + ", FROM_UNIXTIME(" + timestamp + ") ) ON DUPLICATE KEY UPDATE amount = amount + " + measureAmount + ";").
    execute(function(error, rows, cols) {
        if (error) {
            console.log('ERROR: ' + error);
            return;
        }
    });
};


module.exports = MeasurementWorker;