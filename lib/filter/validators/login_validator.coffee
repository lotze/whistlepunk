class LoginValidator

  @validates: (eventJson) ->
    event = JSON.parse eventJson
    event.eventName in ['login', 'loginGuidChange']

module.exports = LoginValidator
