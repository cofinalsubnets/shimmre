fs = require 'fs'
boot = require './bootstrap.js'
shimmreSrc = fs.readFileSync 'shimmre.shimmre', 'utf8'
jscSrc = fs.readFileSync 'jsc.shimmre', 'utf8'
require('./test_shimmre').test 'a compiled-to-js shimmre', eval boot.compile(jscSrc).val[0](shimmreSrc).val[0]
