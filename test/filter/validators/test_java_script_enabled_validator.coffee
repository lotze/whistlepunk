JavaScriptEnabledValidator = require '../../../lib/filter/validators/java_script_enabled_validator'

describe 'JavaScriptEnabledValidator', ->
  describe '.validates', ->

    context "when the event indicates the user has JavaScript enabled", ->
      it "returns true", ->
        @event = {eventName: 'jsCharacteristics'}
        JavaScriptEnabledValidator.validates(JSON.stringify @event).should.be.true

    context "when the event does not indicate that the user has JavaScript enabled", ->
      it "returns false", ->
        @event = {eventName: 'someOtherEvent'}
        JavaScriptEnabledValidator.validates(JSON.stringify @event).should.be.false
