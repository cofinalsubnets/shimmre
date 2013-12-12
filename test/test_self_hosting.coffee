fs = require 'fs'
boot = require '../bootstrap.coffee'
shimmreSrc = fs.readFileSync 'shimmre.shimmre', 'utf8'
require('./test_shimmre').test 'a self-hosted shimmre', boot.compile(shimmreSrc).val[0]
