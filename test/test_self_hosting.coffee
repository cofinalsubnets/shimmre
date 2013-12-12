fs = require 'fs'
boot = require './shimmre.js'
build = require '../build_helpers'
require('./test_shimmre').test 'a self-hosted shimmre', boot.compile(build.srcWithFrontend 'lib/shimmre.shimmre').val[0]
