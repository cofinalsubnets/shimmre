fs = require 'fs'
exec = require('child_process').exec
build = require './build_helpers'

task 'test', 'run tests', ->
  compile = exec "coffee -o test -c lib/shimmre.litcoffee", ->
  compile.on 'close', ->
    test = exec 'mocha --compilers coffee:coffee-script', (err, o, e) -> console.log o; console.log e
    test.on 'close', process.exit

