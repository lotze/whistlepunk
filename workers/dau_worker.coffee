util = require('util')
Worker = require('../lib/worker')
_ = require('underscore')
async = require 'async'
DateFirster = require('../lib/date_firster')
DbLoader = require('../lib/db_loader')
Redis = require("../lib/redis")
config = require('../config')

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
    if json.userId != ""
      @emit 'start'
      try
        # get date from timestamp
        df = new DateFirster(new Date(json.timestamp*1000))
        @client.sadd "dau:#{df.year()}:#{df.month()}:#{df.day()}", json.userId, (err, results) =>
          @emitResults err, results
      catch error
        console.error "Error processing",json," (#{error}): #{error.stack}"
        @emitResults error

module.exports = DauWorker 