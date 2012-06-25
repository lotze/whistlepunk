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

  #
  # Notes... on insert of new share:
  #   1) look up existing count of shares with same share_id from in_from_shares
  #   2) look up status of users from olap_users according to user_id in in_from_shares
  #   3) insert counts of members, invite members, etc back into shares table.
  #


  updateShareMetricsForShare: (shareId, cb) =>
    console.log("updating metrics for #{shareId}")
    myQuery = "
      UPDATE shares, (SELECT 
        sum(in_from_shares.user_id is not null) as up_to_date_num_visits,
        (case when sum(olap_users.status = 'invite_requested_member') is not null then sum(olap_users.status = 'invite_requested_member')
        else 0
        end) as up_to_date_num_requested_members,
        (case when sum(olap_users.status = 'member') is not null then sum(olap_users.status = 'member')
        else 0
        end) as up_to_date_num_members
        FROM
        shares LEFT OUTER JOIN in_from_shares ON shares.share_id=in_from_shares.share_id LEFT OUTER JOIN olap_users ON in_from_shares.user_id = olap_users.id               
        WHERE shares.share_id = '#{@escape shareId}'
      ) as up_to_date_share_results
      SET shares.num_visits=up_to_date_share_results.up_to_date_num_visits, 
      shares.num_invite_requested_members=up_to_date_share_results.up_to_date_num_requested_members, 
      shares.num_members=up_to_date_share_results.up_to_date_num_members
      WHERE shares.share_id = '#{@escape shareId}';
    "
    console.log("executing #{myQuery}")
    @db.query(myQuery).execute cb

  recordShareOrInvitation: (json, measureNames, shareId, shareOrInvitation, shareMethod) =>
    timestamp = json.timestamp
    userId = json.userId

    async.parallel [
      (cb) =>
        async.forEach measureNames, (measureName, measureNameCb) =>
          @dataProvider.measure 'user', userId, timestamp, measureName, json.activityId, '', 1, measureNameCb
        , cb
      (cb) =>
        async.series [
          (seriesCb) =>
            myQuery = "
              INSERT IGNORE INTO shares (sharing_user_id, share_id, share_or_invitation, share_method, created_at)
              VALUES ('#{@escape userId}', '#{@escape shareId}', '#{@escape shareOrInvitation}', '#{@escape shareMethod}', FROM_UNIXTIME(#{timestamp}));
            "
            @db.query(myQuery).execute seriesCb
          (seriesCb) =>
            @updateShareMetricsForShare(shareId, seriesCb)
        ], cb
      (cb) =>
        myQuery = "
          UPDATE olap_users set #{shareOrInvitation}s_created=#{shareOrInvitation}s_created+1 where id='#{@escape userId}';
        "
        @db.query(myQuery).execute cb
    ], @emitResults

  handleCreatedInvitation: (json) =>
    measureNames = ['invited']
    @recordShareOrInvitation json, measureNames, json.invitationId, "invitation", "invitation"

  handleObjectShared: (json) =>
    measureNames = ['shared' , "shared_#{@escape json['shareService']}"]
    @recordShareOrInvitation json, measureNames, json.shareHash, "share", json.shareService

  handleFacebookLike: (json) =>
    measureNames = ['shared' , "shared_facebook_like"]
    @recordShareOrInvitation json, measureNames, json.shareHash, "share", "facebook_like"

  handleFirstRequest: (json) =>
    timestamp = json.timestamp
    userId = json.userId

    if json['fromShare']
      async.parallel [
        (cb) =>
          @dataProvider.addToTimeseries 'share_visited', json.timestamp, cb
        (cb) =>
          myQuery = "
            INSERT IGNORE INTO in_from_shares (user_id, share_id, created_at)
            VALUES ('#{@escape userId}', '#{@escape json['fromShare']}', FROM_UNIXTIME(#{timestamp}))
          "
          @db.query(myQuery).execute cb
        (cb) =>
          myQuery = "
            SELECT sharing_user_id, share_method from shares where share_id = '#{@escape json['fromShare']}'
          "
          @db.query(myQuery).execute (err, rows, cols) =>
            if !err && rows.length > 0
              async.parallel [
                (found_cb) =>
                  @dataProvider.addToTimeseries "share_via_#{@escape rows[0]['share_method']}_visited", json.timestamp, found_cb
                (found_cb) =>
                  @updateShareMetricsForShare(json['fromShare'], found_cb)
              ], cb
            else
              cb()
      ], @emitResults
    else
      @emit 'done'


  handleRespondedToInvitation: (json) =>
    timestamp = json.timestamp
    userId = json.userId

    async.parallel [
      (cb) =>
        @dataProvider.addToTimeseries 'invitation_visited', json.timestamp, cb
      (cb) =>
        # TODO: remove ignore, catch error; only if there is no error should we update the num_visits (since an invitation can be visited by the same user more than once, but we shouldn't count that as multiple visitors)
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
            @updateShareMetricsForShare json['invitationId'], cb
          else
            cb()
    ], @emitResults

  handleMembershipStatusChange: (json) =>
    timestamp = json.timestamp
    userId = json.userId

    async.series [
      (cb) =>
        if json.newState == 'member'
          myQuery = "UPDATE in_from_shares set user_now_member=1 where user_id='#{@escape userId}';"
          @db.query(myQuery).execute cb
        else
          cb()
      (cb) =>
        myQuery = "
          SELECT sharing_user_id, share_or_invitation, shares.share_id as share_id, share_method from in_from_shares join shares on shares.share_id=in_from_shares.share_id where in_from_shares.user_id = '#{@escape userId}'
        "
        @db.query(myQuery).execute (err, rows, cols) =>
          if !err && rows.length > 0
            sharingUserId = rows[0]['sharing_user_id']
            console.log("row is", rows[0])
            shareOrInvitation = rows[0]['share_or_invitation']
            shareId = rows[0]['share_id']
            shareMethod = rows[0]['share_method']
            async.series [
              (cb2) =>
                @dataProvider.addToTimeseries "#{shareOrInvitation}_visitor_became_#{json.newState}", json.timestamp, cb
              (cb2) =>
                @dataProvider.addToTimeseries "#{shareOrInvitation}_visitor_via_#{shareMethod}_became_#{json.newState}", json.timestamp, cb
              (cb2) =>
                @updateShareMetricsForShare shareId, cb2
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
    ], (err, values) =>
      console.log("err is #{err}, results are #{values}")
      @emitResults err, values

module.exports = ShareWorker
