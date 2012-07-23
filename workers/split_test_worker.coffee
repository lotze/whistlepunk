util = require('util')
Worker = require('../lib/worker')
_ = require('underscore')
async = require 'async'
DataProvider = require('../lib/data_provider')
DateFirster = require('../lib/date_firster')
DbLoader = require('../lib/db_loader')

class SplitTestWorker extends Worker
  constructor: (foreman) ->
    @foreman = foreman
    dbloader = new DbLoader()
    @db = dbloader.db()
    @foreman.on('splitTestAssignment', @handleSplitTestAssignment)
    @dataProvider = new DataProvider(foreman)
    super()

  escape: (str...) =>
    return "" unless str? && str[0]?
    @db.escape str...

  init: (callback) ->
    # generally here we need to make sure db connections are opened properly before executing the callback
    callback()

  handleSplitTestAssignment: (json) =>
    @emit 'start'
    try
      timestamp = json.timestamp
      userId = json.userId

      myQuery = "INSERT IGNORE INTO split_test_assignments (experiment_name, assignment, participant_id, created_at) VALUES
        ('#{@db.escape(json.splitTest)}',
        '#{@db.escape(json.assignment)}',
        '#{@db.escape(userId)}',
        #{FROM_UNIXTIME(timestamp)})
      "
      @db.query(myQuery).execute @emitResults
    catch error
      console.error "Error processing",json," (#{error}): #{error.stack}"
      @emitResults error

  # TODO: should we also measure outcomes here?   probably.  probably needs some thought around measurement events and sessions  --TL

module.exports = SplitTestWorker 
