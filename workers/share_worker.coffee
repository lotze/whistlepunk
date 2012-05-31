util = require('util')
Worker = require('../lib/worker')
_ = require('underscore')
async = require 'async'
DataProvider = require('../lib/data_provider')
DbLoader = require('../lib/db_loader')

class ShareWorker extends Worker
  constructor: (foreman) ->
    @foreman = foreman
    dbloader = new DbLoader()
    @db = dbloader.db()
    @foreman.on('createdInvitation', @handleMessage)
    @foreman.on('facebookLiked', @handleMessage)
    @foreman.on('firstRequest', @handleMessage)
    @foreman.on('membershipStatusChange', @handleMessage)
    @foreman.on('objectShared', @handleMessage)
    @foreman.on('respondedToInvitation', @handleMessage)
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
        when "createdInvitation" then @handleCreatedInvitation(json)
        when "facebookLiked" then @handleFacebookLike(json)
        when "firstRequest" then @handleFirstRequest(json)
        when "membershipStatusChange" then @handleMembershipStatusChange(json)
        when "objectShared" then @handleObjectShared(json)
        when "respondedToInvitation" then @handleRespondedToInvitation(json)
        else throw new Error('unhandled eventName');
    catch error
      console.error "Error processing",json," (#{error}): #{error.stack}"
      @emitResults error

  handleObjectShared: (json) =>
    timestamp = json.timestamp
    userId = json.userId

    async.parallel [
      (cb) =>
        myQuery = "
          INSERT IGNORE INTO shares (sharing_user_id, share_id, share_or_invitation, share_method, created_at)
          VALUES ('#{@escape userId}', '#{@escape json['shareHash']}', 'share', '#{@escape json['shareService']}', FROM_UNIXTIME(#{timestamp}));
        "
        @db.query(myQuery).execute cb
      (cb) =>
        myQuery = "
          UPDATE olap_users set shares_created=shares_created+1 where id='#{@escape userId}';
        "
        @db.query(myQuery).execute cb
    ], @emitResults

  handleFacebookLike: (json) =>
    timestamp = json.timestamp
    userId = json.userId

    async.parallel [
      (cb) =>
        myQuery = "
          INSERT IGNORE INTO shares (sharing_user_id, share_id, share_or_invitation, share_method, created_at)
          VALUES ('#{@escape userId}', '#{@escape json['shareHash']}', 'share', 'facebook_like', FROM_UNIXTIME(#{timestamp}));
        "
        @db.query(myQuery).execute cb
      (cb) =>
        myQuery = "
          UPDATE olap_users set shares_created=shares_created+1 where id='#{@escape userId}';
        "
        @db.query(myQuery).execute cb
    ], @emitResults

  handleFirstRequest: (json) =>
    timestamp = json.timestamp
    userId = json.userId

    if json['fromShare']
      async.parallel [
        (cb) =>
          myQuery = "
            INSERT IGNORE INTO in_from_shares (user_id, share_id, created_at)
            VALUES ('#{@escape userId}', '#{@escape json['fromShare']}', FROM_UNIXTIME(#{timestamp}))
          "
          @db.query(myQuery).execute cb
        (cb) =>
          myQuery = "
            SELECT sharing_user_id from shares where share_id = '#{@escape json['fromShare']}'
          "
          @db.query(myQuery).execute (err, rows, cols) =>
            if !err && rows.length > 0
              myQuery = "
                UPDATE shares set num_visits=num_visits+1 where share_id='#{@escape json['fromShare']}';
              "
              @db.query(myQuery).execute cb
            else
              cb()
      ], @emitResults
    else
      @emit 'done'

  handleCreatedInvitation: (json) =>
    timestamp = json.timestamp
    userId = json.userId

    async.parallel [
      (cb) =>
        myQuery = "
          INSERT IGNORE INTO shares (sharing_user_id, share_id, share_or_invitation, share_method, created_at)
          VALUES ('#{@escape userId}', '#{@escape json['invitationId']}', 'invitation', 'invitation', FROM_UNIXTIME(#{timestamp}));
        "
        @db.query(myQuery).execute cb
      (cb) =>
        myQuery = "
          UPDATE olap_users set invitations_created=invitations_created+1 where id='#{@escape userId}';
        "
        @db.query(myQuery).execute cb
    ], @emitResults

  handleRespondedToInvitation: (json) =>
    timestamp = json.timestamp
    userId = json.userId

    async.parallel [
      (cb) =>
        myQuery = "
          INSERT IGNORE INTO in_from_shares (user_id, share_id, created_at)
          VALUES ('#{@escape userId}', '#{@escape json['invitationId']}', FROM_UNIXTIME(#{timestamp}))
        "
        @db.query(myQuery).execute cb
      (cb) =>
        myQuery = "
          SELECT sharing_user_id from shares where share_id = '#{@escape json['invitationId']}'
        "
        @db.query(myQuery).execute (err, rows, cols) =>
          if !err && rows.length > 0
            myQuery = "
              UPDATE shares set num_visits=num_visits+1 where share_id='#{@escape json['invitationId']}';
            "
            @db.query(myQuery).execute cb
          else
            cb()
    ], @emitResults

  handleMembershipStatusChange: (json) =>
    timestamp = json.timestamp
    userId = json.userId

    async.parallel [
      (cb) =>
        if json.newState == 'member'
          myQuery = "UPDATE in_from_shares set user_now_member=1 where user_id='#{@escape userId}';"
          @db.query(myQuery).execute cb
        else
          cb()
      (cb) =>
        myQuery = "
          SELECT sharing_user_id, share_or_invitation, shares.share_id as share_id from in_from_shares join shares on shares.share_id=in_from_shares.share_id where in_from_shares.user_id = '#{@escape userId}'
        "
        @db.query(myQuery).execute (err, rows, cols) =>
          if !err && rows.length > 0
            sharingUserId = rows[0]['sharing_user_id']
            shareOrInvitation = rows[0]['share_or_invitation']
            shareId = rows[0]['share_id']
            async.parallel [
              (cb2) =>
                if json.newState == 'member' || json.newState == 'invite_requested_member'
                  myQuery = "
                    UPDATE shares set num_#{json.newState}s=num_#{json.newState}s+1 where share_id='#{@escape shareId}';
                  "
                  @db.query(myQuery).execute cb2
                else
                  cb2()
              (cb2) =>
                if json.newState == 'member'
                  myQuery = "
                    UPDATE olap_users set members_from_#{shareOrInvitation}s=members_from_#{shareOrInvitation}s+1 where id='#{@escape sharingUserId}';
                  "
                  @db.query(myQuery).execute cb2
                else
                  cb2()
            ], (err, results) =>
              cb err, results
          else
            cb()
    ], @emitResults

module.exports = ShareWorker
