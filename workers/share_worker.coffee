util = require('util')
{EventEmitter} = require('events')
_ = require('underscore')
async = require 'async'
DataProvider = require('../lib/data_provider')
DbLoader = require('../lib/db_loader')

class ShareWorker extends EventEmitter
  constructor: (foreman) ->
    @foreman = foreman
    dbloader = new DbLoader()
    @db = dbloader.db()
    @foreman.on('objectShared', @handleMessage)
    @foreman.on('firstRequest', @handleMessage)
    @foreman.on('createdInvitation', @handleMessage)
    @foreman.on('respondedToInvitation', @handleMessage)
    @foreman.on('membershipStatusChange', @handleMessage)
    @dataProvider = new DataProvider(foreman)

  escape: (str...) =>
    return "" unless str? && str[0]?
    @db.escape str...

  init: (callback) ->
    # generally here we need to make sure db connections are opened properly before executing the callback
    callback()

  handleMessage: (json) =>
    try
      switch json.eventName
        when "objectShared" then @handleObjectShared(json)
        when "firstRequest" then @handleFirstRequest(json)
        when "createdInvitation" then @handleCreatedInvitation(json)
        when "respondedToInvitation" then @handleRespondedToInvitation(json)
        when "membershipStatusChange" then @handleMembershipStatusChange(json)
        else throw new Error('unhandled eventName');
    catch error
      console.error "Error processing",json," (#{error}): #{error.stack}"
      @emit 'done', error

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
    ], (err, results) =>
      @emit 'done', err, results

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
      ], (err, results) =>
        @emit 'done', err, results
    else
      @emit 'done', null, null
    

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
    ], (err, results) =>
      @emit 'done', err, results

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
    ], (err, results) =>
      @emit 'done', err, results

  handleMembershipStatusChange: (json) =>
    timestamp = json.timestamp
    userId = json.userId
    
    async.parallel [
      (cb) =>
        myQuery = "UPDATE in_from_shares set user_now_member=1 where user_id='#{@escape userId}';"
        @db.query(myQuery).execute cb
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
                myQuery = "
                  UPDATE shares set num_members=num_members+1 where share_id='#{@escape shareId}';
                "
                @db.query(myQuery).execute cb2
              (cb2) =>
                myQuery = "
                  UPDATE olap_users set members_from_#{shareOrInvitation}s=members_from_#{shareOrInvitation}s+1 where id='#{@escape sharingUserId}';
                "
                @db.query(myQuery).execute cb2
            ], (err, results) =>
              cb err, results
    ], (err, results) =>
      @emit 'done', err, results


module.exports = ShareWorker 
