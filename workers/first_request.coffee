util = require('util')
{EventEmitter} = require('events')
_ = require('underscore')
async = require 'async'
DataProvider = require('../lib/data_provider')
DateFirster = require('../lib/date_firster')
DbLoader = require('../lib/db_loader')

class FirstRequest extends EventEmitter
  constructor: (foreman) ->
    @foreman = foreman
    dbloader = new DbLoader()
    @db = dbloader.db()
    @foreman.on('firstRequest', @handleFirstRequest)
    @dataProvider = new DataProvider()

  escape: (str...) =>
    @db.escape str...

  init: (callback) ->
    # generally here we need to make sure db connections are openned properly before executing the callback
    callback()

  handleFirstRequest: (json) =>
    normalizedSource = @normalizeSource(json)
    return if normalizedSource == 'Bot'
  
    timestamp = json.timestamp
    userId = json.userId
    
    # users_created_at
    dateFirster = new DateFirster(timestamp)
    actual_date = dateFirster.format()
    first_of_week = dateFirster.firstOfWeek().format()
    first_of_month = dateFirster.firstOfMonth().format()
    

    async.parallel [
      (cb) => 
        @dataProvider.createObject 'user', userId, timestamp, cb
      (cb) =>
        myQuery = "
          INSERT IGNORE INTO users_created_at (user_id, created_at, day, week, month)
          VALUES (
            '#{@db.escape(userId)}', FROM_UNIXTIME(#{timestamp}), '#{actual_date}', '#{first_of_week}', '#{first_of_month}'
          );
        "
        @db.query(myQuery).execute cb
      (cb) =>
        myQuery = "
          INSERT IGNORE INTO olap_users (id, created_at, last_active_at)
          VALUES (
            '#{@db.escape(userId)}', FROM_UNIXTIME(#{timestamp}), FROM_UNIXTIME(#{timestamp})
          );
        "
        @db.query(myQuery).execute cb
      (cb) =>
        locationId = 1001
        countryName = "Tanzania"

        myQuery = "
          INSERT IGNORE INTO sources_users (user_id, source, referrer, request_uri, user_agent, ip_address, country_name, location_id) 
          VALUES ('#{@escape userId}', '#{@escape normalizedSource}', '#{@escape json.referrer}', '#{@escape json.requestUri}', '#{@escape json.userAgent}', '#{@escape json.ip}', '#{@escape countryName}', #{locationId});
        "
        @db.query(myQuery).execute cb
    ], (err, results) =>
      @emit 'done', err, results

    # TODO: advertising tags

  normalizeSource: (data) =>
    return 'Internal Grockit IP' if data.ip in ['206.169.112.34', '98.24.120.2', '75.70.205.199', '68.117.142.136', '108.28.52.133']

    return 'Bot' if @isBot(data.userAgent)

    return 'ad' if /\bc=([^\&]+)/.test(data.requestUri)
      

    if matches = /^https?:\/\/([^\/]+)/.exec(data.referrer)
      return matches[1].split('.').slice(-2).join('.')

    return 'Unknown'

  isBot: (userAgent) =>
    agentExpressions = [/bot/i,/^NewRelicPinger/,/facebookexternalhit/,/^facebook share (http:\/\/facebook.com\/sharer.php)$/,/Grockit/,/spider/i,/Spinn3r/,/Twiceler/,/slurp/,/Ask Jeeves/,/^Chytach/,/^Yandex/,/^panscient/,/^Netvibes/,/^Feed/,/^UniversalFeedParser/,/^PostRank/,/^Apple-PubSub/,/ScoutJet/,/crawler/i,/^Voyager/,/oneriot/,/js-kit/,/backtype.com/,/PycURL/,/Python-urllib/,/^Jakarta Commons-HttpClient/,/^Mozilla\/5.0 \(compatible; Butterfly/,/^NING/,/^Java/,/^Ruby/,/^Twitturly/,/^MetaURI/,/daum/,/MSNPTC/]
    _.any agentExpressions, (ae) -> ae.test(userAgent)

module.exports = FirstRequest 