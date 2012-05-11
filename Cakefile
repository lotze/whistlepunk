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

task 'spec', ->
  process.env.NODE_ENV ?= 'test'
  cmd = './node_modules/.bin/mocha'
  args = spec_opts.concat testFiles()
  run cmd, args

task 'spec:watch', ->
  process.env.NODE_ENV ?= 'test'
  cmd = './node_modules/.bin/mocha'
  args = watch_spec_opts.concat testFiles()
  run cmd, args
