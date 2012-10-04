FullUserValidator = require '../../../lib/filter/validators/full_user_validator'

describe 'FullUserValidator', ->
  describe '.validates', ->

    context "when the event indicates the user is a full user", ->
      it "returns true", ->
        @event = {eventName: 'request', "memberStatus":"full"}
        FullUserValidator.validates(JSON.stringify @event).should.be.true

    context "when the event does not indicate that the user is a full user", ->
      it "returns false", ->
        @event = {eventName: 'request'}
        FullUserValidator.validates(JSON.stringify @event).should.be.false
