build = require '../build_helpers'
boot = require './shimmre'
shimmre = build.compileWithFrontend 'lib/shimmre.shimmjs', boot.eval
require('./test_shimmre').test 'a self-hosted shimmre', shimmre

