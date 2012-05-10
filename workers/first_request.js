var util = require('util'),
    EventEmitter = require('events').EventEmitter,
    _ = require('underscore');

var FirstRequest = function(foreman) {
  this.foreman = foreman;
  EventEmitter.call(this);
  this.foreman.on('firstRequest', this.handleFirstRequest.bind(this));
};

FirstRequest.prototype.init = function(callback) {
  // generally here we need to make sure db connections are openned properly before executing the callback
  callback();
};

FirstRequest.prototype.handleFirstRequest = function(json) {
  var normalizedSource = this.normalizeSource(json);
  if (normalizedSource == 'Bot') {
    return;
  }
  
  locationId = 1001
  countryName = "Tanzania"
  // timestamp gets set properly in foreman when the message comes in so we dont need to do anything in the workers
  
  // insert user record into the users collection
  // insert user into the created at breakdown collection
  // insert into sources users
  
  var tag = (new Regex(/\bc=([^\&]+)/)).exec("\bc=hssssssjk&") // tag will be an array if it is matched
  if (tag != undefined) {
    // insert user stuff into ad_campaign_users
    // insert tagstuff into ad_campaigns collection, the matched tag will be in tag[1] btw
  }
  
};

FirstRequest.prototype.normalizeSource = function(data) {
  if (data.ip == '206.169.112.34' || data.ip == '98.24.120.2' || data.ip == '75.70.205.199' || data.ip == '68.117.142.136' || data.ip == '108.28.52.133')
    return 'Internal Grockit IP'
  end

  if (isBot(data.userAgent))
    return 'Bot'
  end

  if (new RegExp(/\bc=([^\&]+)/).test(data.requestUri))
    return 'ad'
  end

  if (new RegExp(/^https?:\/\/([^\/]+)/).test(data.referrer))
    // js-ify
    // return $1.split('.')[-2..-1].join('.')
  end

  return 'Unknown'
};

FirstRequest.prototype.isBot = function(userAgent) {
  var agentExpressions = [/bot/i,/^NewRelicPinger/,/facebookexternalhit/,/^facebook share (http:\/\/facebook.com\/sharer.php)$/,/Grockit/,/spider/i,/Spinn3r/,/Twiceler/,/slurp/,/Ask Jeeves/,/^Chytach/,/^Yandex/,/^panscient/,/^Netvibes/,/^Feed/,/^UniversalFeedParser/,/^PostRank/,/^Apple-PubSub/,/ScoutJet/,/crawler/i,/^Voyager/,/oneriot/,/js-kit/,/backtype.com/,/PycURL/,/Python-urllib/,/^Jakarta Commons-HttpClient/,/^Mozilla\/5.0 \(compatible; Butterfly/,/^NING/,/^Java/,/^Ruby/,/^Twitturly/,/^MetaURI/,/daum/,/MSNPTC/];
  return _.any(agentExpressions, function(ae){
    return new RegExp(ae).test(userAgent);
  });
};



module.exports = FirstRequest;