LoginValidator = require '../../../lib/filter/validators/login_validator'

describe 'LoginValidator', ->
  describe '.validates', ->

    context "when the event indicates the user logged in", ->
      it "returns true", ->
        @event = {eventName: 'login', userId: 'someUser'}
        LoginValidator.validates(JSON.stringify @event).should.be.true

    context "when the event indicates the user had a GUID change due to logging in", ->
      it "returns true", ->
        @event = {eventName: 'loginGuidChange', userId: 'someUser'}
        LoginValidator.validates(JSON.stringify @event).should.be.true

    context "when the event is not a login-related event", ->
      it "returns false", ->
        @event = {eventName: 'request', client: 'website'}
        LoginValidator.validates(JSON.stringify @event).should.be.false
