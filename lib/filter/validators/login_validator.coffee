class LoginValidator

  @required = false

  @validates: (eventJson) ->
    event = JSON.parse eventJson
    event.eventName in ['login', 'loginGuidChange']

module.exports = LoginValidator
