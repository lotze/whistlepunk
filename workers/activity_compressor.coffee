util = require('util')
Worker = require('../lib/worker')
_ = require('underscore')
async = require 'async'
DateFirster = require('../lib/date_firster')
Db = require('mongodb').Db
Connection = require('mongodb').Connection
Server = require('mongodb').Server

class ActivityCompressor extends Worker
  constructor: (foreman) ->
    @foreman = foreman    
    @mongo = foreman.mongo
    @foreman.on('measureMe', @handleMeasureMe)
    super()

  init: (callback) ->
    # generally here we need to make sure db connections are opened properly before executing the callback
    @mongo.open (err, db) =>
      @mongo.collection 'compressedActivity', (err, compressedActivity) =>
        @daily = compressedActivity
        @daily.ensureIndex {userId: 1, day: 1}, {unique:true}, (err, results) =>
          callback(err, results)

  handleMeasureMe: (json) =>
    console.log("handleMeasureMe", json)
    return unless json.actorType == 'user' && json.measureName in @whiteList()
    @emit 'start'
    modifier = {}
    modifier["actions.#{json.measureName}"] = 1
    console.log("updating ",json," to BEEEEEEEE ", {actions: modifier}," at ", @day(json.timestamp))
    @daily.update({userId: json.actorId, day: @day(json.timestamp)}, {'$inc': modifier}, {upsert: true});
    @emitResults()
    
  whiteList: =>
    ['commented', 'created_board', 'created_invitation', 'created_learning', 'facebook_liked', 'followed', 'liked', 'shared_twitter', 'tagged', 'tag_followed', 'updated_board', 'updated_learning', 'viewed_board', 'viewed_learning']
    
  day: (timestamp) =>
    df = new DateFirster(new Date(1000*timestamp))
    return df.date().unix()
    
module.exports = ActivityCompressor
