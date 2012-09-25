Gate = require '../../lib/filter/gate'
Stream = require 'stream'
should = require 'should'
sinon = require 'sinon'

describe 'Gate', ->
  beforeEach () ->
    @gate = new Gate((eventJson) -> JSON.parse(eventJson).pass)
    @upstream = new Stream()
    @upstream.readable = true
    @upstream.pipe @gate

  describe "#write / #read", ->
    context "when the event passes the discriminator function", ->
      it "makes the event available to be read", (done) ->
        eventJson = JSON.stringify({ pass: true })

        @gate.on 'data', (dataJson) ->
          dataJson.should.eql eventJson
          done()

        @upstream.emit 'data', eventJson


    context "when the event fails the discriminator function", ->
      it "drops the event", (done) ->
        eventJson = JSON.stringify({ pass: false })
        spy = sinon.spy @gate, 'emit'
        @upstream.emit 'data', eventJson
        spy.withArgs('data').called.should.be.false
        done()
