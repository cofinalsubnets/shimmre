fs = require 'fs'
boot = require './shimmre.js'
build = require '../build_helpers'
assert = require 'assert'
shim = boot.compile(build.srcWithFrontend 'lib/shimmre.shimmjs').val[0]
require('./test_shimmre').test 'a self-hosted shimmre', shim

describe 'in a self-hosted shimmre', ->
  describe 'direct left-recursion', ->
    it 'works', ->
      prog = """
        num <- [0-9]+ num -> return Number($);
        main sum <- sum -'+' num | num
        sum -> return $.reduce(function(a,b) {return a + b;});
      """
      sum = shim(prog).val[0]
      assert.equal 10, sum('1+2+3+4').val[0]

