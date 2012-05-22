util = require('util')
Worker = require('../lib/worker')
_ = require('underscore')
async = require 'async'
DataProvider = require('../lib/data_provider')
DateFirster = require('../lib/date_firster')
DbLoader = require('../lib/db_loader')

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
        UPDATE IGNORE olap_users set name='#{@escape json['name']}', email='#{@escape json['email']}' where id='#{@escape userId}';
      "
      @db.query(myQuery).execute @emitResults
    catch error
      console.error "Error processing",json," (#{error}): #{error.stack}"
      @emit 'error', error
      
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
          @dataProvider.measure('user', userId, timestamp, 'upgraded', '', 1, cb)
        (cb) =>
          myQuery = "UPDATE IGNORE olap_users set status='#{@escape json['newState']}' where id='#{@escape userId}';"
          @db.query(myQuery).execute cb
        (cb) =>
          myQuery = "
          INSERT IGNORE INTO users_membership_status_at (user_id, status, timestamp, day, week, month) 
          VALUES ('#{@escape userId}', '#{@escape json['newState']}', FROM_UNIXTIME(#{timestamp}), '#{actual_date}', '#{first_of_week}', '#{first_of_month}' );
          "
          @db.query(myQuery).execute cb
      ], @emitResults
    catch error
      console.error "Error processing",json," (#{error}): #{error.stack}"
      @emit 'error', error

module.exports = MembershipStatusWorker 
