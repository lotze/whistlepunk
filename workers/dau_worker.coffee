util = require('util')
Worker = require('../lib/worker')
_ = require('underscore')
async = require 'async'
DateFirster = require('../lib/date_firster')
DbLoader = require('../lib/db_loader')
Redis = require("../lib/redis")
config = require('../config')
logger = require('../lib/logger')

class DauWorker extends Worker
  constructor: (foreman) ->
    @foreman = foreman
    dbloader = new DbLoader()
    @db = dbloader.db()
    @foreman.on('firstRequest', @handleEvent)
    @foreman.on('request', @handleEvent)
    super()

  escape: (str...) =>
    return "" unless str? && str[0]?
    @db.escape str...

  init: (callback) ->
    Redis.getClient (err, client) =>
      @client = client
      callback(err)

  handleEvent: (json) =>
    userId = json.userId
    if userId != ""
      @emit 'start'
      try
        # get date from timestamp
        df = new DateFirster(new Date(json.timestamp*1000))
        
        myQuery = "SELECT status from users_membership_status_at where user_id = '#{@escape userId}' and timestamp = (SELECT MAX(timestamp) from users_membership_status_at where user_id = '#{@escape userId}');"
        @db.query(myQuery).execute (err, rows, cols) =>
          return @emitResults(err) if err?
          if rows.length > 0
            status = rows[0].status
          else
            status = "visitor"

          @client.sadd "dau:#{status}:#{df.year()}:#{df.month()}:#{df.day()}", userId, (err, results) =>
            @emitResults err, results
      catch error
        logger.error "Error processing",json," (#{error}): #{error.stack}"
        @emitResults error

module.exports = DauWorker 