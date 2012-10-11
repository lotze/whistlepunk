{EventEmitter} = require 'events'
util = require 'util'
logger = require '../lib/logger'

class UnionRep extends EventEmitter
  constructor: (@max = 10000) ->
    @workers = {}
    @count   = {}
    @total   = 0
    @saturated = false
    @drained = true
    # setInterval @report, 10000
    # @on 'saturate', @report
    # @on 'drain', @report

  addWorker: (name, worker) =>
    @workers[name] = worker
    @count[name]   = 0

    worker.on 'start', =>
      @count[name]++
      @total++
      if @total >= @max
        @saturated = true
        @drained = false
        @emit 'saturate' 

    worker.on 'done', =>
      @done(name)
    worker.on 'error', (err) =>
      logger.error "Got an error in a worker: " + err, err.stack
      @done(name)
  
  done: (name) =>
    @count[name]--
    @total--
    if @total <= 0
      @drained = true
      @saturated = false
      @emit 'drain'
      
  report: =>
    logger.info "Worker workloads:", @count
    
module.exports = UnionRep