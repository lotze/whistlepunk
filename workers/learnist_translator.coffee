util = require('util')
Worker = require('../lib/worker')
_ = require('underscore')
async = require 'async'
DataProvider = require('../lib/data_provider')
DbLoader = require('../lib/db_loader')

class LearnistTranslator extends Worker
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
    @foreman.on('facebookLiked', @handleMessage)
    @foreman.on('followed', @handleMessage)
    @foreman.on('liked', @handleMessage)
    @foreman.on('objectShared', @handleMessage)
    @foreman.on('respondedToInvitation', @handleMessage)
    @foreman.on('tagFollowed', @handleMessage)
    @foreman.on('tagUnfollowed', @handleMessage)
    @foreman.on('updatedBoard', @handleMessage)
    @foreman.on('updatedLearning', @handleMessage)
    @foreman.on('userCreated', @handleMessage)
    @foreman.on('viewedBoard', @handleMessage)
    @dataProvider = new DataProvider(foreman)
    super()

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
        when "facebookLiked" then @handleFacebookLiked(json)
        when "followed" then @handleFollowed(json)
        when "liked" then @handleLiked(json)
        when "objectShared" then @handleObjectShared(json)
        when "respondedToInvitation" then @handleRespondedToInvitation(json)
        when "tagFollowed" then @handleTagFollowed(json)
        when "tagUnfollowed" then @handleTagUnfollowed(json)
        when "updatedBoard" then @handleUpdatedBoard(json)
        when "updatedLearning" then @handleUpdatedLearning(json)
        when "userCreated" then @handleUserCreated(json)
        when "viewedBoard" then @handleViewedBoard(json)
        else throw new Error("unhandled eventName: #{json.eventName}");
    catch error
      console.error "Error processing",json," (#{error}): #{error.stack}"
      @emitResults error

  handleCompletedLearning: (json) =>
    async.parallel [
      (cb) => 
        @dataProvider.measure 'user', json.userId, json.timestamp, 'completion', json.activityId, json.boardId?.toString(), 1, cb
      (cb) => 
        if json.isFinalLearning
          @dataProvider.measure 'user', json.userId, json.timestamp, 'completed_all_board_learnings', json.activityId, json.boardId?.toString(), 1, cb
        else
          cb(null,null)
      (cb) => 
        @dataProvider.measure 'board', json.boardId.toString(), json.timestamp, 'had_learning_completed', json.activityId, json.userId, 1, cb
    ], @emitResults
      
  handleCommentAdd: (json) =>
    async.parallel [
      (cb) => 
        @dataProvider.measure 'board', json.boardId?.toString(), json.timestamp, 'commented_on', json.activityId, json.userId, 1, cb
      (cb) =>
        @dataProvider.measure 'user', json.userId, json.timestamp, 'commented', json.activityId, '', 1, cb
    ], @emitResults

  handleCreatedBoard: (json) =>
    async.parallel [
      (cb) => 
        @dataProvider.measure 'user', json.userId, json.timestamp, 'created_board', json.activityId, '', 1, cb
      (cb) => 
        @dataProvider.createObject 'board', json.boardId?.toString(), json.timestamp, cb
      (cb) => 
        @dataProvider.incrementOlapUserCounter json.userId, 'boards_created', cb
    ], @emitResults

  handleCreatedInvitation: (json) =>
    async.parallel [
      (cb) => 
        @dataProvider.measure 'user', json.userId, json.timestamp, 'created_invitation', json.activityId, json.boardId, 1, cb
      (cb) => 
        @dataProvider.createObject 'invitation', json.invitationId, json.timestamp, cb
    ], @emitResults

  handleCreatedLearning: (json) =>
    async.parallel [
      (cb) => 
        @dataProvider.measure 'user', json.userId, json.timestamp, 'created_learning', json.activityId, json.boardId?.toString(), 1, cb
      (cb) => 
        if json.boardId?
          @dataProvider.measure 'board', json.boardId.toString(), json.timestamp, 'added_learning', json.activityId, json.userId, 1, cb
        else
          cb()
    ], @emitResults

  handleCreatedTag: (json) =>
    @dataProvider.measure 'user', json.userId, json.timestamp, 'tagged', json.activityId, json.taggableId?.toString(), 1, @emitResults

  handleEmailSent: (json) =>
    async.parallel [
      (cb) => 
        @dataProvider.measure 'user', json.userId, json.timestamp, 'received_email', json.activityId, json.emailType, 1, cb
      (cb) => 
        @dataProvider.createObject 'system_email', json.shareHash, json.timestamp, cb
      (cb) => 
        @dataProvider.createObject "system_email_#{json.emailType}", json.shareHash, json.timestamp, cb
    ], @emitResults
    
  handleFacebookLiked: (json) =>
    @dataProvider.measure 'board', json.boardId?.toString(), json.timestamp, 'facebook_liked', json.activityId, json.userId, 1, @emitResults

  handleFollowed: (json) =>
    @dataProvider.measure 'user', json.userId, json.timestamp, 'followed', json.activityId, json.subscriptionTargetId?.toString(), 1, @emitResults

  handleLiked: (json) =>
    share_id = json.shareHash || "#{json.targetType}_#{json.targetId}"
    @dataProvider.measure 'user', json.userId, json.timestamp, 'liked', json.activityId, share_id, 1, @emitResults

  handleRespondedToInvitation: (json) =>
    @dataProvider.measure 'invitation', json.invitationId, json.timestamp, 'invitation_responded_to', json.activityId, json.userId, 1, @emitResults

  handleTagFollowed: (json) =>
    @dataProvider.measure 'user', json.userId, json.timestamp, 'tag_followed', json.activityId, json.tagId?.toString(), 1, @emitResults

  handleTagUnfollowed: (json) =>
    @dataProvider.measure 'user', json.userId, json.timestamp, 'tag_unfollowed', json.activityId, json.tagId?.toString(), 1, @emitResults

  handleUpdatedBoard: (json) =>
    async.parallel [
      (cb) => 
        @dataProvider.measure 'user', json.userId, json.timestamp, 'updated_board', json.activityId, '', 1, cb
      (cb) => 
        @dataProvider.measure 'board', json.boardId, json.timestamp, "updated", json.activityId, '', 1, cb
    ], @emitResults

  handleUpdatedLearning: (json) =>
    async.parallel [
      (cb) => 
        @dataProvider.measure 'user', json.userId, json.timestamp, 'updated_board', json.activityId, '', 1, cb
      (cb) => 
        @dataProvider.measure 'user', json.userId, json.timestamp, "updated_learning", json.activityId, '', 1, cb
      (cb) => 
        @dataProvider.measure 'board', json.boardId, json.timestamp, "updated_learning", json.activityId, '', 1, cb
    ], @emitResults

  handleUserCreated: (json) =>
    async.parallel [
      (cb) => 
        if json.invitationId
          @dataProvider.measure 'invitation', json.invitationId, json.timestamp, 'created_membership_from_invitation', json.activityId, '', 1, cb
        else
          cb(null, null)
    ], @emitResults
  
  handleViewedBoard: (json) =>
    async.parallel [
      (cb) => 
        @dataProvider.measure 'board', json.boardId?.toString(), json.timestamp, 'viewed', json.activityId, json.userId, 1, cb
      (cb) => 
        @dataProvider.measure 'user', json.userId, json.timestamp, 'viewed_board', json.activityId, json.boardId?.toString(), 1, cb
      (cb) => 
        @dataProvider.incrementOlapUserCounter json.userId, 'board_viewings', cb
    ], @emitResults

module.exports = LearnistTranslator