util = require('util')
Worker = require('../lib/worker')
_ = require('underscore')
async = require 'async'
DataProvider = require('../lib/data_provider')
DateFirster = require('../lib/date_firster')
DbLoader = require('../lib/db_loader')
logger = require('../lib/logger')

class MembershipStatusWorker extends Worker
  constructor: (foreman) ->
    @foreman = foreman
    dbloader = new DbLoader()
    @db = dbloader.db()
    @foreman.on('userCreated', @handleUserCreated)
    @foreman.on('membershipStatusChange', @handleMembershipStatusChange)
    @dataProvider = new DataProvider(foreman)
    super()

  escape: (str...) =>
    return "" unless str? && str[0]?
    @db.escape str...

  init: (callback) ->
    # generally here we need to make sure db connections are opened properly before executing the callback
    callback()

  handleUserCreated: (json) =>
    @emit 'start'
    try
      timestamp = json.timestamp
      userId = json.userId
    
      myQuery = "
        INSERT INTO olap_users (id, name, email) VALUES ('#{@escape userId}', '#{@escape json['name']}', '#{@escape json['email']}') ON DUPLICATE KEY UPDATE name='#{@escape json['name']}', email='#{@escape json['email']}';
      "
      @db.query(myQuery).execute @emitResults
    catch error
      logger.error "Error processing",json," (#{error}): #{error.stack}"
      @emitResults error
      
  handleMembershipStatusChange: (json) =>
    @emit 'start'
    try
      timestamp = json.timestamp
      userId = json.userId
      dateFirster = new DateFirster(new Date(1000*timestamp))
      actual_date = dateFirster.format()
      first_of_week = dateFirster.firstOfWeek().format()
      first_of_month = dateFirster.firstOfMonth().format()

      async.parallel [
        (cb) => 
          @dataProvider.createObject json['newState'], userId, timestamp, cb
        (cb) => 
          @dataProvider.measure('user', userId, timestamp, "upgraded_to_#{json.newState}", json.activityId, '', 1, cb)
        (cb) =>
          async.series [
            (status_cb) =>
              myQuery = "
              INSERT IGNORE INTO users_membership_status_at (user_id, status, timestamp, day, week, month) 
              VALUES ('#{@escape userId}', '#{@escape json['newState']}', FROM_UNIXTIME(#{timestamp}), '#{actual_date}', '#{first_of_week}', '#{first_of_month}' );
              "
              @db.query(myQuery).execute status_cb
            (status_cb) =>
              myQuery = "SELECT status from users_membership_status_at where user_id = '#{@escape userId}' and timestamp = (SELECT MAX(timestamp) from users_membership_status_at where user_id = '#{@escape userId}');"
              @db.query(myQuery).execute (err, rows, cols) =>
                status_cb(err) if err?
                status = rows[0].status
                myQuery = "INSERT INTO olap_users (id, status) VALUES ('#{@escape userId}', '#{@escape status}') ON DUPLICATE KEY UPDATE status='#{@escape status}';"
                @db.query(myQuery).execute status_cb
          ], cb
      ], @emitResults
    catch error
      logger.error "Error processing",json," (#{error}): #{error.stack}"
      @emitResults error

module.exports = MembershipStatusWorker 
