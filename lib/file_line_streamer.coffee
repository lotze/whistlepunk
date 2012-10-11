fs = require("fs")
{EventEmitter} = require 'events'
util = require 'util'
logger = require '../lib/logger'


class FileLineStreamer extends EventEmitter
  constructor: (@filename) ->
    @buffer = ''

  start: =>
    @stream = fs.createReadStream(@filename, encoding: 'utf8')
    @stream.on 'error', (err) ->
      logger.error("Error reading from stream for #{@filename}", err)
    @stream.on 'end', =>
      @emit 'data', @buffer if @buffer.length
      @emit 'end'
    @stream.on 'data', (data) =>
      @buffer += data
      parts = @buffer.split "\n"
      @buffer = parts.pop()
      @emit('data', part) for part in parts

  pause: =>
    @stream.pause()

  resume: =>
    @stream.resume()

module.exports = FileLineStreamer