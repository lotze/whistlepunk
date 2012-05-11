util = require('util')
_ = require('underscore')
async = require 'async'
DbLoader = require('../lib/db_loader')

class DataProvider
  constructor: () ->
    dbloader = new DbLoader()
    @db = dbloader.db()

  escape: (str...) =>
    @db.escape str...
    
  createObject: (objectType, objectId, createdAt, callback) =>
    async.parallel [
      (cb) =>
        myQuery = "INSERT IGNORE INTO all_objects (object_id, object_type, created_at) VALUES ('#{@escape objectId}', '#{@escape objectType}', FROM_UNIXTIME(#{createdAt}));"
        @db.query(myQuery).execute cb
      (cb) =>
        myQuery = "UPDATE summarized_metrics SET raw_data_last_updated_at=UNIX_TIMESTAMP(NOW()) WHERE object_filter_type='#{@escape objectType}' AND measurement_transform='ever_performed'"
        @db.query(myQuery).execute cb
    ], (err, results) =>
      callback err, results
      
  measure: (actorType, actorId, timestamp, measureName, measureTarget='', measureAmount=1, callback) =>
    async.parallel [
      (cb) =>
        myQuery = "
          INSERT INTO all_measurements (object_id, object_type, measure_name, measure_target, amount, first_time) 
          VALUES ('#{@escape actorId}', '#{@escape(actorType)}', '#{@escape(measureName)}', '#{@escape(measureTarget)}', #{measureAmount}, FROM_UNIXTIME(#{timestamp}) ) ON DUPLICATE KEY UPDATE amount = amount + #{measureAmount};
        "
        @db.query(myQuery).execute cb
      (cb) =>
        myQuery = "UPDATE summarized_metrics SET raw_data_last_updated_at=UNIX_TIMESTAMP(NOW()) WHERE measure_name='#{@escape measureName}'"
        @db.query(myQuery).execute cb
    ], (err, results) =>
      callback err, results

module.exports = DataProvider