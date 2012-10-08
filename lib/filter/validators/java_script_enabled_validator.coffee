class JavaScriptEnabledValidator

  @required = false

  @validates: (eventJson) ->
    event = JSON.parse eventJson
    event.eventName == "jsCharacteristics"

module.exports = JavaScriptEnabledValidator