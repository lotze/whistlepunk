util = require('util')
{EventEmitter} = require('events')
_ = require('underscore')
async = require 'async'
DataProvider = require('../lib/data_provider')
DbLoader = require('../lib/db_loader')

class LearnistTranslator extends EventEmitter
  constructor: (foreman) ->
    @foreman = foreman
    dbloader = new DbLoader()
    @db = dbloader.db()
    @foreman.on('completedLearning', @handleMessage)
    @foreman.on('commentAdd', @handleMessage)
    @foreman.on('createdBoard', @handleMessage)
    @foreman.on('completedLearning', @handleMessage)
    @foreman.on('createdInvitation', @handleMessage)
    @foreman.on('createdLearning', @handleMessage)
    @foreman.on('createdTag', @handleMessage)
    @foreman.on('emailSent', @handleMessage)
    @foreman.on('followed', @handleMessage)
    @foreman.on('liked', @handleMessage)
    @foreman.on('objectShared', @handleMessage)
    @foreman.on('request', @handleMessage)
    @foreman.on('respondedToInvitation', @handleMessage)
    @foreman.on('tagFollowed', @handleMessage)
    @foreman.on('tagUnfollowed', @handleMessage)
    @foreman.on('updatedLearning', @handleMessage)
    @foreman.on('userCreated', @handleMessage)
    @foreman.on('viewedBoard', @handleMessage)
    @dataProvider = new DataProvider(foreman)

  escape: (str...) =>
    return "" unless str? && str[0]?
    @db.escape str...

  init: (callback) ->
    # generally here we need to make sure db connections are opened properly before executing the callback
    callback()
    
  handleMessage: (json) =>
    @emit 'start'
    try
      switch json.eventName
        when "completedLearning" then @handleCompletedLearning(json)
        when "commentAdd" then @handleCommentAdd(json)
        when "createdBoard" then @handleCreatedBoard(json)
        when "completedLearning" then @handleCompletedLearning(json)
        when "createdInvitation" then @handleCreatedInvitation(json)
        when "createdLearning" then @handleCreatedLearning(json)
        when "createdTag" then @handleCreatedTag(json)
        when "emailSent" then @handleEmailSent(json)
        when "followed" then @handleFollowed(json)
        when "liked" then @handleLiked(json)
        when "objectShared" then @handleObjectShared(json)
        when "request" then @handleRequest(json)
        when "respondedToInvitation" then @handleRespondedToInvitation(json)
        when "tagFollowed" then @handleTagFollowed(json)
        when "tagUnfollowed" then @handleTagUnfollowed(json)
        when "updatedLearning" then @handleUpdatedLearning(json)
        when "userCreated" then @handleUserCreated(json)
        when "viewedBoard" then @handleViewedBoard(json)
        else throw new Error('unhandled eventName');
    catch error
      console.error "Error processing",json," (#{error}): #{error.stack}"
      @emit 'done', error
      

  handleCompletedLearning: (json) =>
    async.parallel [
      (cb) => 
        @dataProvider.measure 'user', json.userId, json.timestamp, 'completion', json.boardId?.toString(), 1, cb
      (cb) => 
        if json.isFinalLearning
          @dataProvider.measure 'user', json.userId, json.timestamp, 'completed_all_board_learnings', json.boardId?.toString(), 1, cb
        else
          cb(null,null)
      (cb) => 
        @dataProvider.measure 'board', json.boardId.toString(), json.timestamp, 'had_learning_completed', json.userId, 1, cb
    ], (err, results) =>
      @emit 'done', err, results
      
  handleCommentAdd: (json) =>
    @dataProvider.measure 'user', json.userId, json.timestamp, 'commented', '', 1, (err, results) =>
      @emit 'done', err, results

  handleCreatedBoard: (json) =>
    async.parallel [
      (cb) => 
        @dataProvider.measure 'user', json.userId, json.timestamp, 'created_board', '', 1, cb
      (cb) => 
        @dataProvider.createObject 'board', json.boardId?.toString(), json.timestamp, cb
      (cb) => 
        @dataProvider.incrementOlapUserCounter json.userId, 'boards_created', cb
    ], (err, results) =>
      @emit 'done', err, results

  handleCreatedInvitation: (json) =>
    async.parallel [
      (cb) => 
        @dataProvider.measure 'user', json.userId, json.timestamp, 'created_invitation', json.boardId, 1, cb
      (cb) => 
        @dataProvider.createObject 'invitation', json.invitationId, json.timestamp, cb
    ], (err, results) =>
      @emit 'done', err, results

  handleCreatedLearning: (json) =>
    @dataProvider.measure 'user', json.userId, json.timestamp, 'created_learning', json.boardId?.toString(), 1, (err, results) =>
      @emit 'done', err, results

  handleCreatedTag: (json) =>
    @dataProvider.measure 'user', json.userId, json.timestamp, 'tagged', json.taggableId?.toString(), 1, (err, results) =>
      @emit 'done', err, results

  handleEmailSent: (json) =>
    async.parallel [
      (cb) => 
        @dataProvider.measure 'user', json.userId, json.timestamp, 'received_email', json.emailType, 1, cb
      (cb) => 
        @dataProvider.createObject 'system_email', json.shareHash, json.timestamp, cb
      (cb) => 
        @dataProvider.createObject "system_email_#{json.emailType}", json.shareHash, json.timestamp, cb
    ], (err, results) =>
      @emit 'done', err, results

  handleFollowed: (json) =>
    @dataProvider.measure 'user', json.userId, json.timestamp, 'followed', json.subscriptionTargetId?.toString(), 1, (err, results) =>
      @emit 'done', err, results

  handleLiked: (json) =>
    share_id = json.shareHash || "#{json.targetType}_#{json.targetId}"
    async.parallel [
      (cb) => 
        @dataProvider.measure 'user', json.userId, json.timestamp, 'liked', share_id, 1, cb
      (cb) => 
        @dataProvider.createObject 'like', share_id, json.timestamp, cb
    ], (err, results) =>
      @emit 'done', err, results

  handleObjectShared: (json) =>
    async.parallel [
      (cb) => 
        @dataProvider.measure 'user', json.userId, json.timestamp, 'shared', '', 1, cb
      (cb) => 
        @dataProvider.measure 'user', json.userId, json.timestamp, "shared_#{json.shareService}", '', 1, cb
      (cb) => 
        @dataProvider.createObject 'share', json.shareHash, json.timestamp, cb
      (cb) => 
        @dataProvider.createObject "share_#{json.shareService}", json.shareHash, json.timestamp, cb
    ], (err, results) =>
      @emit 'done', err, results

  handleRequest: (json) =>
    async.parallel [
      (cb) => 
        if json.fromShare
          @dataProvider.measure 'share', json.fromShare, json.timestamp, 'share_visited', json.userId, 1, cb
        else
          cb(null, null)
    ], (err, results) =>
      @emit 'done', err, results

  handleRespondedToInvitation: (json) =>
    @dataProvider.measure 'user', 'invitation', json.timestamp, 'invitation_responded_to', json.userId, 1, (err, results) =>
      @emit 'done', err, results

  handleTagFollowed: (json) =>
    @dataProvider.measure 'user', json.userId, json.timestamp, 'tag_followed', json.tagId?.toString(), 1, (err, results) =>
      @emit 'done', err, results

  handleTagUnfollowed: (json) =>
    @dataProvider.measure 'user', json.userId, json.timestamp, 'tag_unfollowed', json.tagId?.toString(), 1, (err, results) =>
      @emit 'done', err, results

  handleUpdatedLearning: (json) =>
    async.parallel [
      (cb) => 
        @dataProvider.measure 'user', json.userId, json.timestamp, 'updated_board', '', 1, cb
      (cb) => 
        @dataProvider.measure 'user', json.userId, json.timestamp, "updated_learning", '', 1, cb
    ], (err, results) =>
      @emit 'done', err, results

  handleUserCreated: (json) =>
    async.parallel [
      (cb) => 
        if json.invitationId
          @dataProvider.measure 'invitation', json.invitationId, json.timestamp, 'created_membership_from_invitation', '', 1, cb
        else
          cb(null, null)
    ], (err, results) =>
      @emit 'done', err, results
  
  handleViewedBoard: (json) =>
    async.parallel [
      (cb) => 
        # console.log "uid is #{json.userId}, ts is #{json.timestamp}, board id is #{json.boardI}"
        @dataProvider.measure 'user', json.userId, json.timestamp, 'viewed_board', json.boardId?.toString(), 1, cb
      (cb) => 
        @dataProvider.incrementOlapUserCounter json.userId, 'board_viewings', cb
    ], (err, results) =>
      @emit 'done', err, results

module.exports = LearnistTranslator