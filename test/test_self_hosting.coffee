###
fs = require 'fs'
boot = require './shimmre.js'
build = require '../build_helpers'
assert = require 'assert'
src = build.srcWithFrontend 'lib/shimmre.shimmjs'
shim = boot.compile(src).val[0]
shimtests = require './test_shimmre'
shimtests.test 'a self-hosted shimmre', shim
shimtests.test 'a self-hosted-hosted shimmre', shim(src).val[0]

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

  describe 'indirect left-recursion', ->
    it 'works', ->
      prog = """
        num <- [0-9]+ num -> return Number($);
        add3 <- sum
        add2 <- "nowaybro" | add3
        add1 <- add2
        main sum <- add1 -'+' num | num
        sum -> return $.reduce(function(a,b) {return a + b;});
      """
      sum = shim(prog).val[0]
      assert.equal 10, sum('0+1+2+3+4').val[0]

  describe 'the frontend', ->
    it 'is implemented correctly', ->
      front = build.src('lib/grammar.shimmre')
      fshim = shim(front.toString()).val[0]
      res = fshim 'main a <- b'
      assert res
      assert res.rem is ''


###
