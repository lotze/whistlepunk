class JavaScriptEnabledValidator

  @required = false

  @validates: (eventJson) ->
    event = JSON.parse eventJson
    event.eventName == "jsCharacteristics" && event.jsEnabled == true

module.exports = JavaScriptEnabledValidator