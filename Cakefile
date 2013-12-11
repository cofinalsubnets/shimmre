fs = require 'fs'

compile = (infile, outfile) ->
  boot = require './bootstrap'
  fs.readFile infile, 'utf8', (e,data) ->
    fs.readFile './jsc.shimmre', 'utf8', (e,jsc) ->
      fs.writeFile outfile, boot.compile(jsc)(data).val[0]

task 'build:shimmre', 'compile shimmre.shimmre to javascript', ->
  compile './shimmre.shimmre', './shimmre.js'
task 'build:jsc', 'compile shimmre.jsc to javascript', ->
  compile './jsc.shimmre', './jsc.js'

