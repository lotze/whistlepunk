util = require('util')
Worker = require('../lib/worker')
_ = require('underscore')
async = require 'async'
DataProvider = require('../lib/data_provider')
DateFirster = require('../lib/date_firster')
DbLoader = require('../lib/db_loader')
logger = require('../lib/logger')

class IOSWorker extends Worker
  constructor: (foreman) ->
    @foreman = foreman
    dbloader = new DbLoader()
    @db = dbloader.db()
    @foreman.on('registeredDevice', @handleIOS)
    @foreman.on('MobileAppStart', @handleIOS)
    @dataProvider = new DataProvider(foreman)
    super()

  escape: (str...) =>
    return "" unless str? && str[0]?
    @db.escape str...

  init: (callback) ->
    # generally here we need to make sure db connections are opened properly before executing the callback
    callback()

  handleIOS: (json) =>
    @emit 'start'
    try
      normalizedSource = json.client
      if (json.client == ' app' && json.deviceType?)
        normalizedSource = json.deviceType + ' app'
      normalizedSource = normalizedSource.toLowerCase();
  
      timestamp = json.timestamp
      userId = json.userId
    
      # users_created_at
      dateFirster = new DateFirster(new Date(1000*timestamp))
      actual_date = dateFirster.format()
      first_of_week = dateFirster.firstOfWeek().format()
      first_of_month = dateFirster.firstOfMonth().format()

      async.parallel [
        (cb) => 
          @dataProvider.createObject 'user', userId, timestamp, cb
        (cb) =>
          myQuery = "
            INSERT IGNORE INTO olap_users (id, created_at)
            VALUES (
              '#{@db.escape(userId)}', FROM_UNIXTIME(#{timestamp})
            );
          "
          @db.query(myQuery).execute cb
        (cb) =>
          myQuery = "
            INSERT IGNORE INTO users_created_at (user_id, created_at, day, week, month)
            VALUES (
              '#{@db.escape(userId)}', FROM_UNIXTIME(#{timestamp}), '#{actual_date}', '#{first_of_week}', '#{first_of_month}'
            );
          "
          @db.query(myQuery).execute cb
        (cb) =>
          myQuery = "
            INSERT IGNORE INTO sources_users (user_id, source)
            VALUES (
              '#{@db.escape(userId)}', '#{@db.escape(normalizedSource)}'
            );
          "
          @db.query(myQuery).execute cb
      ], @emitResults
    catch error
      logger.error "Error processing",json," (#{error}): #{error.stack}"
      @emitResults error

module.exports = IOSWorker 
