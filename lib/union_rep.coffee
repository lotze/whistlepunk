{EventEmitter} = require 'events'
util = require 'util'

class UnionRep extends EventEmitter
  constructor: (@max = 10000) ->
    @workers = {}
    @count   = {}
    @total   = 0
    setInterval @report, 10000
    @on 'saturate', @report

  addWorker: (name, worker) =>
    @workers[name] = worker
    @count[name]   = 0

    worker.on 'start', =>
      @count[name]++
      @total++
      @emit 'saturate' if @total >= @max

    worker.on 'done', =>
      @count[name]--
      @total--
      @emit 'drain' if @total <= 0

  report: =>
    console.log("Worker workloads:")
    console.log util.inspect(@count)
    
module.exports = UnionRep