util = require('util')
moment = require 'moment'
_ = require('underscore')
async = require 'async'
DbLoader = require('../lib/db_loader')
DateFirster = require('../lib/date_firster')
{EventEmitter} = require('events')

class DataProvider extends EventEmitter
  constructor: (foreman) ->
    @foreman = foreman
    dbloader = new DbLoader()
    @db = dbloader.db()

  escape: (str) =>
    return "" unless str? && str[0]?
    @db.escape str.toString()
    
  incrementOlapUserCounter: (userId, counterName, callback) =>
    myQuery = "INSERT INTO olap_users (id, #{@escape counterName}) VALUES ('#{@escape userId}',1) ON DUPLICATE KEY update #{@escape counterName}=#{@escape counterName}+1;"
    @db.query(myQuery).execute callback

  addToTimeseries: (measureName, timestamp, callback) =>
    dateFirster = new DateFirster(new Date(1000*timestamp))
    async.parallel [
      (timeseries_cb) =>
        # update timeseries for day
        aggregate_moment = dateFirster.date()
        myQuery = "INSERT INTO timeseries (measure_name, aggregation_level, timestamp, formatted_timestamp, amount) VALUES ('#{@escape measureName}', 'day', #{aggregate_moment.unix()}, '#{aggregate_moment.format()} US/Pacific', 1) ON DUPLICATE KEY UPDATE amount = amount + 1;"
        @db.query(myQuery).execute timeseries_cb
      (timeseries_cb) =>
        # update timeseries for month
        aggregate_moment = dateFirster.firstOfMonth()
        myQuery = "INSERT INTO timeseries (measure_name, aggregation_level, timestamp, formatted_timestamp, amount) VALUES ('#{@escape measureName}', 'month', #{aggregate_moment.unix()}, '#{aggregate_moment.format()} US/Pacific', 1) ON DUPLICATE KEY UPDATE amount = amount + 1;"
        @db.query(myQuery).execute timeseries_cb
      (timeseries_cb) =>
        # update timeseries for year
        aggregate_moment = dateFirster.firstOfYear()
        myQuery = "INSERT INTO timeseries (measure_name, aggregation_level, timestamp, formatted_timestamp, amount) VALUES ('#{@escape measureName}', 'year', #{aggregate_moment.unix()}, '#{aggregate_moment.format()} US/Pacific', 1) ON DUPLICATE KEY UPDATE amount = amount + 1;"
        @db.query(myQuery).execute timeseries_cb
      (timeseries_cb) =>
        # update timeseries for total
        myQuery = "INSERT INTO timeseries (measure_name, aggregation_level, timestamp, formatted_timestamp, amount) VALUES ('#{@escape measureName}', 'total', 0, '', 1) ON DUPLICATE KEY UPDATE amount = amount + 1;"
        @db.query(myQuery).execute timeseries_cb
    ], callback
    
  createObject: (objectType, objectId, createdAt, callback) =>
    async.parallel [
      (cb) =>
        myQuery = "INSERT IGNORE INTO all_objects (object_id, object_type, created_at) VALUES ('#{@escape objectId}', '#{@escape objectType}', FROM_UNIXTIME(#{createdAt}));"
        @db.query(myQuery).execute cb
      (cb) =>
        myQuery = "UPDATE summarized_metrics SET raw_data_last_updated_at=UNIX_TIMESTAMP(NOW()) WHERE object_filter_type='#{@escape objectType}' AND measurement_transform='ever_performed'"
        @db.query(myQuery).execute cb
      (cb) =>
        @addToTimeseries "new #{objectType} created", createdAt, cb
    ], (err, results) =>
      callback err, results
      
  measure: (actorType, actorId, timestamp, measureName, activityId, measureTarget='', measureAmount=1, callback) =>
    #console.trace("meeeeaasssure: #{actorType}, #{actorId}, #{measureName}, #{timestamp}")
    async.parallel [
      (cb) =>
        # console.log("dp measuring ",actorType, actorId, timestamp, measureName, activityId)
        @foreman.processMessage({eventName:'measureMe', actorType: actorType, actorId: actorId, timestamp: timestamp, activityId: activityId, measureName: measureName, measureTarget: measureTarget, measureAmount: measureAmount}) if @foreman
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
        if actorType == 'user'
          @addToTimeseries measureName, timestamp, cb
        else
          cb()
    ], (err, results) =>
      callback err, results

module.exports = DataProvider