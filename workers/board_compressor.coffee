util = require('util')
Worker = require('../lib/worker')
_ = require('underscore')
async = require 'async'
config = require('../config')
DateFirster = require('../lib/date_firster')
Db = require('mongodb').Db
Connection = require('mongodb').Connection
Server = require('mongodb').Server

class BoardCompressor extends Worker
  constructor: (foreman) ->
    @foreman = foreman    
    @mongo = new Db(config.mongo_db_name, new Server(config.mongo_db_server, config.mongo_db_port, {}), {})
    @foreman.on('measureMe', @handleMeasureMe)
    super()

  init: (callback) ->
    # generally here we need to make sure db connections are opened properly before executing the callback
    @mongo.open (err, db) =>
      @mongo.collection 'compressedBoardActivity', (err, compressedBoardActivity) =>
        @daily = compressedBoardActivity
        @daily.ensureIndex {boardId: 1, day: 1}, {unique:true}, (err, results) =>
          callback(err, results)

  handleMeasureMe: (json) =>
    return unless json.actorType == 'board' && json.measureName in @whiteList()
    @emit 'start'
    modifier = {}
    modifier["actions.#{json.measureName}"] = 1
    @daily.update({boardId: json.actorId, day: @day(json.timestamp)}, {'$inc': modifier}, {upsert: true});
    @emitResults()
    
  whiteList: =>
    ['added_learning', 'commented_on', 'facebook_liked', 'updated', 'updated_learning', 'viewed']
    
  day: (timestamp) =>
    df = new DateFirster(new Date(1000*timestamp))
    return df.date().unix()
    
module.exports = BoardCompressor
