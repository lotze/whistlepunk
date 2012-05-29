{EventEmitter} = require 'events'

class Worker extends EventEmitter
  constructor: ->
    super()
  emitResults: (err, results) =>
    if err?
      console.log("emitting error from worker: ",err,err.stack)
      @emit 'error', err
    else
      @emit 'done', results

module.exports = Worker