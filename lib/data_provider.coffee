util = require('util')
moment = require 'moment'
_ = require('underscore')
async = require 'async'
DbLoader = require('../lib/db_loader')
{EventEmitter} = require('events')

class DataProvider extends EventEmitter
  constructor: (foreman) ->
    @foreman = foreman
    dbloader = new DbLoader()
    @db = dbloader.db()

  escape: (str...) =>
    @db.escape str...
    
  incrementOlapUserCounter: (userId, counterName, callback) =>
    myQuery = "UPDATE olap_users set #{@escape counterName}=#{@escape counterName}+1 where id='#{@escape userId}';"
    @db.query(myQuery).execute callback
    
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
        @foreman.emit('measureMe', {actorType: actorType, actorId: actorId, timestamp: timestamp, measureName: measureName, measureTarget: measureTarget, measureAmount: measureAmount}) if @foreman
        cb(null, null)
      (cb) =>
        myQuery = "
          INSERT INTO all_measurements (object_id, object_type, measure_name, measure_target, amount, first_time) 
          VALUES ('#{@escape actorId}', '#{@escape actorType}', '#{@escape measureName}', '#{@escape measureTarget}', #{measureAmount}, FROM_UNIXTIME(#{timestamp}) ) ON DUPLICATE KEY UPDATE amount = amount + #{measureAmount};
        "
        @db.query(myQuery).execute cb
      (cb) =>
        myQuery = "UPDATE summarized_metrics SET raw_data_last_updated_at=UNIX_TIMESTAMP(NOW()) WHERE measure_name='#{@escape measureName}'"
        @db.query(myQuery).execute cb
      (cb) =>
        # update timeseries for day
        aggregate_moment = moment(timestamp).hours(0).minutes(0).seconds(0)
        myQuery = "INSERT INTO timeseries (measure_name, aggregation_level, timestamp, formatted_timestamp, amount) VALUES ('#{@escape measureName}', 'day', #{aggregate_moment.unix()}, '#{aggregate_moment.format("YYYY-MM-DD")} US/Pacific', 1) ON DUPLICATE KEY UPDATE amount = amount + 1;"
        @db.query(myQuery).execute cb
      (cb) =>
        # update timeseries for month
        aggregate_moment = moment(timestamp).date(1).hours(0).minutes(0).seconds(0)
        myQuery = "INSERT INTO timeseries (measure_name, aggregation_level, timestamp, formatted_timestamp, amount) VALUES ('#{@escape measureName}', 'month', #{aggregate_moment.unix()}, '#{aggregate_moment.format("YYYY-MM-DD")} US/Pacific', 1) ON DUPLICATE KEY UPDATE amount = amount + 1;"
        @db.query(myQuery).execute cb
      (cb) =>
        # update timeseries for year
        aggregate_moment = moment(timestamp).month(0).date(1).hours(0).minutes(0).seconds(0)
        myQuery = "INSERT INTO timeseries (measure_name, aggregation_level, timestamp, formatted_timestamp, amount) VALUES ('#{@escape measureName}', 'year', #{aggregate_moment.unix()}, '#{aggregate_moment.format("YYYY-MM-DD")} US/Pacific', 1) ON DUPLICATE KEY UPDATE amount = amount + 1;"
        @db.query(myQuery).execute cb
      (cb) =>
        # update timeseries for total
        myQuery = "INSERT INTO timeseries (measure_name, aggregation_level, timestamp, formatted_timestamp, amount) VALUES ('#{@escape measureName}', 'total', 0, '', 1) ON DUPLICATE KEY UPDATE amount = amount + 1;"
        @db.query(myQuery).execute cb
        
    ], (err, results) =>
      callback err, results

module.exports = DataProvider