class ValidUserChecker
  constructor: (@redis) ->
    @key = "event:" + process.env.NODE_ENV + ":valid_users"

  isValid: (eventJson, callback) =>
    event = JSON.parse(eventJson)
    @redis.zscore @key, event.userId, (err, reply) =>
      if err?
        console.error err.stack
        callback false
      else if reply?
        callback true
      else
        callback false

  destroy: (cb) =>
    @redis.quit ->
      cb?()

module.exports = ValidUserChecker
