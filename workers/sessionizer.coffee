util = require('util')
{EventEmitter} = require('events')
_ = require('underscore')
async = require 'async'
DataProvider = require('../lib/data_provider')
DateFirster = require('../lib/date_firster')
DbLoader = require('../lib/db_loader')
redis = require("redis")
crypto = require("crypto")
config = require('../config')

# sessionizer maintains a hash (by user), a set, and a sorted set (by user/end time) in redis to determine the aspects of all currently-active user sessions:
#  - sessionizer:start_time  start time of the session
#  - sessionizer:is_first    whether the session is the user's first session
#  - sessionizer:end_time    end time of the session

# sessonizer also maintains a hash (by user) and sorted set (by user/end_time) of recently created users to see if they come back on their next day:
#  - sessionizer:next_day_start
#  - sessionizer:next_day_end

# sessionizer maintains a string (integer) value of the number of requests processed since last cleaning, to figure out when to clean out old next-day sessions
#  - sessionizer:requests_processed

class Sessionizer extends EventEmitter
  constructor: (foreman) ->
    @foreman = foreman
    dbloader = new DbLoader()
    @db = dbloader.db()
    @foreman.on('firstRequest', @handleFirstRequest)
    @foreman.on('request', @handleRequest)
    @foreman.on('measureMe', @handleMeasureMe)
    @dataProvider = new DataProvider(foreman)
    @cleanRequestFrequency = 10000
    @sessionIntervalSeconds = 900

  escape: (str...) =>
    return "" unless str? && str[0]?
    @db.escape str...

  init: (callback) ->
    # generally here we need to make sure db connections are opened properly before executing the callback
    @client = redis.createClient(config.redis.port, config.redis.host)
    @client.on "error", (err) ->
      console.log("Error " + err);
    @client.on "ready", (err) =>
      @client.set 'sessionizer:requests_processed', '0', callback
    @queue = async.queue @processRequest, 1

  handleMeasureMe: (json) =>
    try
      if json.actorType == 'user'
        @client.hget ['sessionizer:start_time', json.userId], (err, start_time) =>
          if start_time
            @dataProvider.measure 'session', @sessionId(start_time,json.userId), json.timestamp, json.measureName, json.measureTarget, json.measureAmount
    catch error
      console.error "Error processing",json," (#{error}): #{error.stack}"
      @emit 'done', error
            
  handleFirstRequest: (json) =>
    try
      @client.sadd('sessionizer:is_first', json.userId)
      # TODO: compute and store the user's next-day return range
      next_day = json.timestamp # Note: this needs to be computed based on the user's time zone...which is just IP-based now, sadly
      @client.hsetnx 'sessionizer:next_day_start', json.userId, next_day
      @client.zadd 'sessionizer:next_day_end', next_day + 86400, json.userId
      @handleRequest(json)
    catch error
      console.error "Error processing",json," (#{error}): #{error.stack}"
      @emit 'done', error
      
  handleRequest: (json) =>
    try
      @queue.push {data: json}, (err) =>
        if err?
          console.error "Error executing queue for", json, "the error was:", err
    catch error
      console.error "Error processing",json," (#{error}): #{error.stack}"
      @emit 'done', error
        
  processRequest: (data, callback) =>
    json = data.data
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
                    @dataProvider.measure 'user', json.userId, json.timestamp, 'returned_next_local_day', '', 1, next_day_cb
                ], (err, results) =>
                  req_cb err, results
              else
                req_cb null, null
          else
            req_cb null, null
    ], (err, results) =>
      @emit 'done', err, results
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
        async.parallel [
          (cb) => @client.hget 'sessionizer:start_time', userId, cb
          (cb) => @client.zscore 'sessionizer:end_time', userId, cb
          (cb) => @client.sismember 'sessionizer:is_first', userId, cb
        ], (err, results) =>
          throw err if err?
          [startTime, endTime, isFirst] = results
          seconds = endTime - startTime
          sessionId = @sessionId(startTime, userId)
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
                @dataProvider.measure 'user', userId, startTime, 'returned', '', 1, cb
            (cb) =>
              @dataProvider.createObject session_type, sessionId, startTime, cb
            (cb) =>
              @client.zrem 'sessionizer:end_time', userId, cb
            (cb) =>
              @client.hdel 'sessionizer:start_time', userId, cb
            (cb) =>
              @client.srem 'sessionizer:is_first', userId, cb
          ], (err, results) =>
            user_cb(err, results)
      , (err, results) =>
        callback err, results

  cleanOutOld: (before_timestamp) =>
    # get all users with next_day_end before before_timestamp (now); remove them from next_day_start and next_day_end
    async.series [
      (cb) => 
        @client.zrangebyscore 'sessionizer:next_day_end', -1, before_timestamp, (err, results) =>
          async.forEachSeries results, (key, key_cb) =>
            @client.hdel 'sessionizer:next_day_start', key, key_cb
          , cb
      (cb) => 
        @client.zremrangebyscore 'sessionizer:end_time', -1, before_timestamp
    ]

module.exports = Sessionizer 