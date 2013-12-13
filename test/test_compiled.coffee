fs = require 'fs'
boot = require './shimmre.js'
build = require '../build_helpers'
jsc = build.compiler()
src = build.srcWithFrontend 'lib/shimmre.shimmjs'

require('./test_shimmre').test 'a compiled-to-js shimmre', eval jsc(src).val[0]
