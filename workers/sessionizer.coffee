util = require('util')
Worker = require('../lib/worker')
_ = require('underscore')
async = require 'async'
DataProvider = require('../lib/data_provider')
DateFirster = require('../lib/date_firster')
DbLoader = require('../lib/db_loader')
Redis = require("../lib/redis")
crypto = require("crypto")
config = require('../config')
logger = require('../lib/logger')

# sessionizer maintains data objects in redis to determine the aspects of all currently-active user sessions:
#  - sessionizer:start_time  hash by user; start time of the session
#  - sessionizer:is_first    set; whether the session is the user's first session
#  - sessionizer:activity_id hash by user; activityId for the current session
#  - sessionizer:end_time    sorted set; end time of the session

# sessonizer also maintains a hash (by user) and sorted set (by user/end_time) of recently created users to see if they come back on their next day:
#  - sessionizer:next_day_start
#  - sessionizer:next_day_end

# sessionizer maintains a string (integer) value of the number of requests processed since last cleaning, to figure out when to clean out old next-day sessions
#  - sessionizer:requests_processed

class Sessionizer extends Worker
  constructor: (foreman) ->
    @foreman = foreman
    dbloader = new DbLoader()
    @db = dbloader.db()
    @foreman.on('firstRequest', @enqueueEvent)
    @foreman.on('request', @enqueueEvent)
    @foreman.on('measureMe', @enqueueEvent)
    @dataProvider = new DataProvider(@foreman)
    @cleanRequestFrequency = 10000
    @sessionIntervalSeconds = 900
    @eventTracker = {}
    super()

  escape: (str...) =>
    return "" unless str? && str[0]?
    @db.escape str...

  init: (callback) ->
    @queue = async.queue @popQueue, 1
    Redis.getClient (err, client) =>
      @client = client
      @client.set 'sessionizer:requests_processed', '0', callback

  popQueue: (data, queueCallback) =>
    json = data.json
    try
      if (json.eventName == 'measureMe')
        @handleMeasureMe(json, queueCallback)
      else
        @handleRequest(json, queueCallback)
    catch error
      logger.error "Error processing ",json," (#{error}): #{error.stack}"
      queueCallback error

  enqueueEvent: (json) =>
    @emit 'start'
    @queue.push {json: json}, (err, results) =>
      @emitResults err, results
    
  handleMeasureMe: (json, callback) =>
    try
      #console.log("handling measurement ", json)
      if json.actorType == 'user' && json.measureName != 'returned' && json.measureName != 'returned_next_local_day'
        #console.log("   it's a kind we care about")
        if json.activityId?
          #console.log("   it has activity")
          @dataProvider.measure 'session', json.activityId, json.timestamp, json.measureName, json.activityId, json.measureTarget, json.measureAmount, callback
        else
          #console.log("   no activity")
          async.parallel [
            (cb) => @client.hget 'sessionizer:start_time', json.actorId, cb
            (cb) => @client.hget 'sessionizer:activity_id', json.actorId, cb
          ], (err, results) =>
            return callback(err) if err?
            [startTime, activityId] = results
            if startTime?
              #console.log("   it has start time #{startTime}, activity #{activityId}")
              @dataProvider.measure 'session', activityId || @sessionId(startTime,json.actorId), json.timestamp, json.measureName, json.activityId, json.measureTarget, json.measureAmount, callback
            else
              #console.log("   it has no activity")
              callback()
      else
        #console.log("   we don't care")
        callback()
    catch error
      #console.error "Error processing",json," (#{error}): #{error.stack}"
      callback(error)

  handleRequest: (json, callback) =>
    if json.userId?
      async.series [
        (processing_cb) =>
          if json.eventName == 'firstRequest'
            # TODO: actually compute based on time zone
            # begin
            #   tz = TZInfo::Timezone.get(user_time_zone)
            # rescue Exception => e
            #   tz = TZInfo::Timezone.get("US/Pacific")
            # end
            # local_time = tz.utc_to_local(Time.at(session.start_time).utc)
            # # create end_of_first_day (next 3 AM), end_of_second_day (following 3 AM), and see if the timestamp is between them
            # three_am_this_day = tz.local_to_utc(Time.utc(local_time.year,local_time.month,local_time.day,3,0,0))
            # end_of_first_day = nil
            # if (local_time.strftime("%H").to_i >= 3)
            #   end_of_first_day = three_am_this_day + 86400
            # else
            #   end_of_first_day = three_am_this_day
            # end
            next_day = json.timestamp + 86400
            async.series [
              (cb) => @client.sadd 'sessionizer:is_first', json.userId, cb
              (cb) => @client.hsetnx 'sessionizer:next_day_start', json.userId, next_day, cb
              (cb) => @client.zadd 'sessionizer:next_day_end', next_day + 86400, json.userId, cb
            ], processing_cb
          else
            processing_cb()
        (processing_cb) => 
          if json.activityId
            @client.hsetnx 'sessionizer:activity_id', json.userId, json.activityId, processing_cb
          else
            processing_cb()
        (processing_cb) =>
          @processRequest json, processing_cb
      ], callback
    else
      callback()

  processRequest: (json, callback) =>
    async.parallel [
      # check to see if we should do cleaning out of old states
      (req_cb) => 
        @client.incr 'sessionizer:requests_processed', (err, val) =>
          if val > @cleanRequestFrequency
            @cleanOutOld(json.timestamp)
            @client.set 'sessionizer:requests_processed', '0'
          req_cb null, null

      (req_cb) => 
          # handle any closed connections
          @processClosedSessions json.timestamp - @sessionIntervalSeconds, (err, results) =>
            async.series [
              # see if this user has a current session; if not, set their start_time
              (new_ses_cb) =>
                @client.hsetnx 'sessionizer:start_time', json.userId, json.timestamp, new_ses_cb
              (new_ses_cb) =>
                # always update this user's end_time
                @client.zadd 'sessionizer:end_time', json.timestamp, json.userId, new_ses_cb
            ], req_cb
      
      # see if the user is in next_day_start
      (req_cb) =>
        @client.hexists 'sessionizer:next_day_start', json.userId, (err, inNextDay) =>
          if inNextDay
            # if so, and their time is > next_day_start, see if they are < next_day_end
            # if so, mark them as returned and remove them from next_day_start and next_day_end
            async.parallel [
              (cb) =>
                @client.hget 'sessionizer:next_day_start', json.userId, cb
              (cb) =>
                @client.zscore 'sessionizer:next_day_end', json.userId, cb
            ], (err, results) =>
              [nextDayStart, nextDayEnd] = results
              if nextDayStart < json.timestamp < nextDayEnd
                @client.hdel 'sessionizer:next_day_start', json.userId 
                @client.zrem 'sessionizer:next_day_end', json.userId
                async.parallel [
                  (next_day_cb) =>
                    @db.query("UPDATE IGNORE olap_users SET returned_next_day=1 WHERE id = '#{@escape json.userId}'").execute next_day_cb
                  (next_day_cb) =>
                    @dataProvider.measure 'user', json.userId, json.timestamp, 'returned_next_local_day', null, '', 1, next_day_cb
                ], (err, results) =>
                  req_cb err, results
              else
                req_cb null, null
          else
            req_cb null, null
    ], (err, results) =>
      # Calls back to the queue, which emits error or done
      callback(err, results)

  sessionId: (timestamp, userId) ->
    hash = crypto.createHash('md5')
    hash.update("#{timestamp}#{userId}",'ascii')
    return hash.digest('hex')  # we should maybe store this rather than recomputing it from start_time/userId each time the session gets measured...

  processClosedSessions: (before_timestamp, callback) =>
    # get all users with end_time before before_timestamp (15 minutes ago); for each one, process their info from start_time/is_first/end_time and remove
    @client.zrangebyscore 'sessionizer:end_time', -1, before_timestamp, (err, userIds) =>
      if userIds.length == 0
        callback err, null
      nonblankUserIds = (userId for userId in userIds when userId isnt '')
      async.forEach nonblankUserIds, (userId, user_cb) =>
        #console.log("closing session for #{userId}")
        async.parallel [
          (cb) => @client.hget 'sessionizer:start_time', userId, cb
          (cb) => @client.zscore 'sessionizer:end_time', userId, cb
          (cb) => @client.sismember 'sessionizer:is_first', userId, cb
          (cb) => @client.hget 'sessionizer:activity_id', userId, cb
        ], (err, results) =>
          throw err if err?
          [startTime, endTime, isFirst, sessionId] = results
          sessionId = @sessionId(startTime, userId) unless sessionId?
          #console.log("  started at #{startTime}, ended at #{endTime}, was first? #{isFirst}")
          seconds = endTime - startTime
          if (seconds < 0)
            seconds=0
          if isFirst
            update_sql = "UPDATE IGNORE olap_users SET num_sessions=num_sessions+1, seconds_on_site=seconds_on_site + #{seconds}, first_session_seconds = #{seconds} WHERE id = '#{@escape userId}';"
            session_type = 'first_session'
            @client.srem 'sessionizer:is_first', userId
          else
            update_sql = "UPDATE IGNORE olap_users SET num_sessions=num_sessions+1, seconds_on_site=seconds_on_site + #{seconds} WHERE id = '#{@escape userId}';"
            session_type = 'nonfirst_session'
          async.parallel [
            (cb) =>
              @db.query(update_sql).execute cb
            (cb) =>
              @dataProvider.createObject 'session', sessionId, startTime, cb
            (cb) =>
              if isFirst
                cb null, null
              else
                #console.log("measuring 'returned' for #{userId}/#{sessionId}")
                @dataProvider.measure 'user', userId, startTime, 'returned', sessionId, '', 1, cb
            (cb) =>
              @dataProvider.createObject session_type, sessionId, startTime, cb
            (cb) =>
              @client.zrem 'sessionizer:end_time', userId, cb
            (cb) =>
              @client.hdel 'sessionizer:start_time', userId, cb
            (cb) =>
              @client.hdel 'sessionizer:activity_id', userId, cb
            (cb) =>
              @client.srem 'sessionizer:is_first', userId, cb
          ], (err, results) =>
            user_cb(err, results)
      , (err, results) =>
        callback err, results

  cleanOutOld: (before_timestamp, callback) =>
    # get all users with next_day_end before before_timestamp (now); remove them from next_day_start and next_day_end
    async.series [
      (cb) => 
        @client.zrangebyscore 'sessionizer:next_day_end', -1, before_timestamp, (err, results) =>
          async.forEachSeries results, (key, key_cb) =>
            @client.hdel 'sessionizer:next_day_start', key, key_cb
          , cb
      (cb) => 
        @client.zremrangebyscore 'sessionizer:end_time', -1, before_timestamp, cb
    ], (err, results) =>
      callback?()

module.exports = Sessionizer 