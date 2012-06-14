#!/usr/bin/env coffee

process.env.NODE_ENV ?= 'development'

require('coffee-script')

Foreman = require('./lib/foreman')

process.on 'uncaughtException', (e) ->
  console.error("UNCAUGHT EXCEPTION: ", e, e.stack)

quit = ->
  process.exit(0)

process.on('SIGINT', quit)
process.on('SIGKILL', quit)

class Application
  constructor: (@foreman) ->
    console.log("Creating application")

  terminate: =>
    @foreman.terminate()

  run: =>
    @foreman.init (err) =>
      @foreman.addAllWorkers (err) =>
        throw err if err?
        @startProcessing()

  startProcessing: =>
    console.log "WhistlePunk: connecting foreman to remote redis"
    @foreman.connect (err) =>
      throw err if err?
      console.log 'WhistlePunk: running...'

app = new Application(new Foreman())

process.on 'SIGKILL', ->
  app.terminate()

process.on 'SIGINT', ->
  app.terminate()

exports =
  run: app.run
  terminate: app.terminate

app.run()
