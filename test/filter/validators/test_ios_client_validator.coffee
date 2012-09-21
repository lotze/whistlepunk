IosClientValidator = require '../../../lib/filter/validators/ios_client_validator'

describe 'IosClientValidator', ->
  describe '#validates', ->

    context "when the event indicates the user is using the iPad app", ->
      it "returns true", ->
        @event = {eventName: 'request', client: 'iPad app'}
        IosClientValidator.validates(JSON.stringify @event).should.be.true

    context "when the event indicates the user is using the iPhone app", ->
      it "returns true", ->
        @event = {eventName: 'request', client: 'iPhone app'}
        IosClientValidator.validates(JSON.stringify @event).should.be.true

    context "when the event does not indicate that the user has javascript enabled", ->
      it "returns false", ->
        @event = {eventName: 'request', client: 'website'}
        IosClientValidator.validates(JSON.stringify @event).should.be.false
