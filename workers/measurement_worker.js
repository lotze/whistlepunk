var MeasurementWorker = function () {
  var mysql = require('db-mysql');
  this.db = new mysql.Database({
    hostname: 'localhost',
    user: 'root',
    password: 'password',
    database: 'metricizer_test'
  });
  this.db.on('error', function(error) {
    console.log('ERROR: ' + error);
  // }).on('ready', function(server) {
  //   console.log('Connected to ' + server.hostname + ' (' + server.version + ')');
  }).connect({async: false});
}

MeasurementWorker.prototype = {
  db: function() {
    return this.db;
  },
  processLog: function (logHash) {
  if (logHash['eventName'] == 'measureMe') {
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
    return 1;
  } else {
    return 0;
  }
  }
}

exports.MeasurementWorker = MeasurementWorker