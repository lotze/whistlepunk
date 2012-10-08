class FullUserValidator

  @required = false

  @validates: (eventJson) ->
    event = JSON.parse eventJson
    event.memberStatus == 'full' || event.memberStatus == 'limited'

module.exports = FullUserValidator
