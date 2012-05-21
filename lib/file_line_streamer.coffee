fs = require("fs")
{EventEmitter} = require 'events'
util = require 'util'

class FileLineStreamer extends EventEmitter
  constructor: (@filename) ->
    console.log("FileLineStreamer constructor: #{@filename}")
    @showMemory()
    @buffer = ''

    @dataCount = 0
    @on 'data', =>
      @dataCount++
      if @dataCount >= 10000
        @dataCount = 0
        @showMemory()

  start: =>
    @stream = fs.createReadStream(@filename, encoding: 'utf8')
    @stream.on 'error', (err) ->
      console.error("Error reading from stream for #{@filename}", err)
    @stream.on 'end', =>
      @emit 'data', @buffer if @buffer.length
      @emit 'end'
    @stream.on 'data', (data) =>
      process.stdout.write '.'
      @buffer += data
      parts = @buffer.split "\n"
      @buffer = parts.pop()
      @emit('data', part) for part in parts

  pause: =>
    @stream.pause()

  resume: =>
    @stream.resume()

  showMemory: =>
    console.log "Current Memory Usage: ", util.inspect(process.memoryUsage())

module.exports = FileLineStreamer