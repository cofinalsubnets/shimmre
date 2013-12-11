fs = require 'fs'

compileAndWrite = (infile, outfile) ->
  boot = require './bootstrap'
  fs.readFile infile, 'utf8', (e,data) ->
    fs.readFile './jsc.shimmre', 'utf8', (e,jsc) ->
      fs.writeFile outfile, boot.compile(jsc)(data).val[0]

compileAndLoad = (infile, cb) ->
  boot = require './bootstrap'
  fs.readFile infile, 'utf8', (e,data) ->
    fs.readFile './jsc.shimmre', 'utf8', (e,jsc) ->
      cb eval boot.compile(jsc)(data).val[0]

task 'build:shimmre', 'compile shimmre.shimmre to javascript', ->
  compileAndWrite './shimmre.shimmre', './shimmre.js'
task 'build:jsc', 'compile shimmre.jsc to javascript', ->
  compileAndWrite './jsc.shimmre', './jsc.js'

task 'test', 'run tests', ->
  require('child_process').exec 'mocha --compilers coffee:coffee-script',
    (err, o, e) ->
      console.log o
      console.log e

