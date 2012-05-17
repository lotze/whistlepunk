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
    @db.escape str...

  init: (callback) ->
    # generally here we need to make sure db connections are opened properly before executing the callback
    @client = redis.createClient(config.redis.port, config.redis.host)
    @client.on "error", (err) ->
      console.log("Error " + err);
    @client.on "ready", (err) =>
      @client.set 'sessionizer:requests_processed', '0', callback

  handleMeasureMe: (json) =>
    if json.actorType == 'user'
      @client.hget ['sessionizer:start_time', json.userId], (err, start_time) =>
        if start_time
          @dataProvider.measure 'session', @sessionId(start_time,json.userId), json.timestamp, json.measureName, json.measureTarget, json.measureAmount, (err, results) =>
            @emit 'done', err, results
        else
          @emit 'done', null, null
    else
      @emit 'done', null, null
      
  handleFirstRequest: (json) =>
    @client.sadd('sessionizer:is_first', json.userId)
    # TODO: compute and store the user's next-day return range
    next_day = json.timestamp # Note: this needs to be computed based on the user's time zone...which is just IP-based now, sadly
    @client.hset 'sessionizer:next_day_start', json.userId, next_day
    @client.zadd 'sessionizer:next_day_end', next_day + 86400, json.userId
    @handleRequest(json)

  handleRequest: (json) =>
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
            console.log("processed closed sessions")
            async.parallel [
              # see if this user has a current session; if not, set their start_time
              (new_ses_cb) =>
                console.log("processing request by " + json.userId)
                @client.hexists 'sessionizer:start_time', json.userId, (err, exists) =>
                  if exists
                    new_ses_cb null, null
                  else
                    @client.hset 'sessionizer:start_time', json.userId, json.timestamp, new_ses_cb
              (new_ses_cb) =>
                # update this user's end_time
                console.log("setting end time for " + json.userId)
                @client.zadd 'sessionizer:end_time', json.timestamp, json.userId, new_ses_cb
            ], req_cb
      
      # see if the user is in next_day_start
      (req_cb) =>
        if @client.hexists 'sessionizer:next_day_start', json.userId
          # if so, and their time is > next_day_start, see if they are < next_day_end
          # if so, mark them as returned and remove them from next_day_start and next_day_end
          if @client.hget 'sessionizer:next_day_start', json.userId < json.timestamp && json.timestamp < @client.zscore 'sessionizer:next_day_end', json.userId
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

  sessionId: (timestamp, userId) ->
    hash = crypto.createHash('md5')
    hash.update("#{timestamp}#{userId}",'ascii')
    return hash.digest('hex')  # we should maybe store this rather than recomputing it from start_time/userId each time the session gets measured...

  processClosedSessions: (before_timestamp, callback) =>
    # get all users with end_time before before_timestamp (15 minutes ago); for each one, process their info from start_time/is_first/end_time and remove
    console.log("Checking zrangebyscore sessionizer:end_time -1 #{before_timestamp}")
    @client.zrangebyscore 'sessionizer:end_time', -1, before_timestamp, (err, userIds) =>
      console.log(userIds)
      if userIds.length == 0
        console.log("No users with sessions to close")
        callback err, null
      async.forEach userIds, (userId, user_cb) =>
        console.log("closing a session for " + userId)
        @client.hget 'sessionizer:start_time', userId, (err, startTime) =>
          @client.zscore 'sessionizer:start_time', userId, (err, endTime) =>
            @client.sismember 'sessionizer:is_first', userId, (err, isFirst) =>
              seconds = endTime - startTime
              sessionId = @sessionId(startTime, userId)
              if (seconds < 0)
                console.log("Weird/error session of negative length from #{userId}, lasting from #{startTime} to #{endTime}")
                seconds=0
              if isFirst
                update_sql = "UPDATE IGNORE olap_users SET num_sessions=num_sessions+1, seconds_on_site=seconds_on_site + #{seconds}, first_session_seconds = #{seconds} WHERE id = '#{@escape userId}';"
                session_type = 'first_session'
                @client.srem 'sessionizer:is_first', userId
              else
                update_sql = "UPDATE IGNORE olap_users SET num_sessions=num_sessions+1, seconds_on_site=seconds_on_site + #{seconds} WHERE id = '#{@escape userId}';"
                session_type = 'nonfirst_session'
              console.log("About to go run session sql: #{update_sql}")  
              async.parallel [
                (cb) =>
                  @db.query(update_sql).execute cb
                (cb) =>
                  @dataProvider.createObject 'session', sessionId, startTime, cb
                (cb) =>
                  if isFirst
                    cb null, null
                  else
                    @dataProvider.measure 'user', json.userId, json.timestamp, 'returned', '', 1, cb
                (cb) =>
                  @dataProvider.createObject session_type, sessionId, startTime, cb
                (cb) =>
                  @client.hdel 'sessionizer:start_time', userId, cb
                (cb) =>
                  @client.srem 'sessionizer:is_first', userId, cb
              ], (err, results) =>
                user_cb(err, results)
        , (err, results) =>
          @client.zremrangebyscore 'sessionizer:end_time', -1, before_timestamp, (err, results) =>
            callback err, results

  cleanOutOld: (before_timestamp) =>
    # get all users with next_day_end before before_timestamp (now); remove them from next_day_start and next_day_end
    async.series [
      (cb) => 
        @client.zrangebyscore 'sessionizer:next_day_end', -1, before_timestamp, (err, results) =>
          @client.hdel 'sessionizer:next_day_start'
      (cb) => 
        @client.zremrangebyscore 'sessionizer:end_time', -1, before_timestamp
    ]

module.exports = Sessionizer 