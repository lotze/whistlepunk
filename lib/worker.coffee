{EventEmitter} = require 'events'

class Worker extends EventEmitter
  constructor: ->
    super
  emitResults: (err, results) =>
    if err?
      @emit 'error', err
    else
      @emit 'done', results

module.exports = Worker