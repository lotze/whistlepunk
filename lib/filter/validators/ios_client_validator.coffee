class IosClientValidator

  @validates: (eventJson) ->
    event = JSON.parse eventJson
    event.client in ['iPad app', 'iPhone app']

module.exports = IosClientValidator