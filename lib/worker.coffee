{EventEmitter} = require 'events'

class Worker extends EventEmitter
  constructor: ->
    super()
  emitResults: (err, results) =>
    if err?
      console.trace("emitting error from worker: ",err)
      @emit 'error', err
    else
      @emit 'done', results

module.exports = Worker