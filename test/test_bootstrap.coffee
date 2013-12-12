fs = require 'fs'
boot = require './bootstrap.js'
require('./test_shimmre').test 'the bootstrapper', boot.compile
