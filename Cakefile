{spawn} = require 'child_process'
findit  = require 'findit'

spec_opts = ['--compilers', 'coffee:coffee-script', '--colors', '--require', 'should', '-R', 'spec']
watch_spec_opts = spec_opts.concat ['--watch', '--growl', '--reporter', 'min']

run = (cmd, args) ->
  proc = spawn cmd, args
  proc.stdout.pipe(process.stdout, end: false)
  proc.stderr.pipe(process.stderr, end: false)

testFiles = ->
  files = findit.sync 'test'
  (file for file in files when file.match /^test_.*\.(js|coffee)$/)

option '-f', '--file [FILE]', 'set a single file for `cake spec` to run on'

task 'spec', (options) ->
  process.env.NODE_ENV ?= 'test'
  process.env.TZ = 'US/Pacific'
  cmd = './node_modules/.bin/mocha'
  filesToTest = options.file or testFiles()
  args = spec_opts.concat filesToTest
  run cmd, args

task 'spec:watch', ->
  process.env.NODE_ENV ?= 'test'
  process.env.TZ = 'US/Pacific'
  cmd = './node_modules/.bin/mocha'
  args = watch_spec_opts.concat testFiles()
  run cmd, args
