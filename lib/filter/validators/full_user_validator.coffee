class FullUserValidator

  @required = false

  @validates: (eventJson) ->
    event = JSON.parse eventJson
    event.memberStatus == 'full'

module.exports = FullUserValidator
