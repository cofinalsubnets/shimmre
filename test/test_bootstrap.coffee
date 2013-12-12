fs = require 'fs'
boot = require '../bootstrap.coffee'
require('./test_shimmre').test 'the bootstrapper', boot.compile
