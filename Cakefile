{spawn} = require 'child_process'
findit  = require 'findit'

spec_opts = ['--compilers', 'coffee:coffee-script', '--colors', '--require', 'should', '-R', 'spec']
watch_spec_opts = spec_opts.concat ['--watch', '--growl', '--reporter', 'min']

run = (cmd, args) ->
  proc = spawn cmd, args
  proc.stdout.pipe(process.stdout, end: false)
  proc.stderr.pipe(process.stderr, end: false)

testFiles = (dir) ->
  files = if dir? then findit.sync dir else findit.sync 'test'
  (file for file in files when file.match /test_.*\.(js|coffee)$/)

option '-f', '--file [FILE]', 'set a single file or directory for `cake spec` to run on'
option '-r', '--reporter [REPORTER]', 'set a reporter for Mocha specs'

task 'spec', (options) ->
  process.env.NODE_ENV ?= 'test'
  process.env.TZ = 'US/Pacific'
  cmd = './node_modules/.bin/mocha'
  filesToTest = testFiles(options.file)
  args = spec_opts
  if options.reporter
    index = args.indexOf '--reporter'
    if index == -1
      args = args.concat ['--reporter', options.reporter]
    else
      args.splice index, 0, options.reporter
  args = args.concat filesToTest
  run cmd, args

task 'spec:watch', (options) ->
  process.env.NODE_ENV ?= 'test'
  process.env.TZ = 'US/Pacific'
  cmd = './node_modules/.bin/mocha'
  args = watch_spec_opts.concat testFiles(options.file)
  run cmd, args
