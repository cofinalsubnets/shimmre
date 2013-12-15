fs = require 'fs'
boot = require './shimmre.js'
assert = require 'assert'
build = require '../build_helpers'
testShimmre = require('./test_shimmre').test

testShimmre 'the evaluator', boot.eval
testShimmre 'the compiler', (s) ->
  res = boot.compile s
  {val: res.val.map(eval), rem: res.rem}

describe 'reference checking', ->
  describe 'when an undefined parse rule is referenced', ->
    data =
      tag: 'document'
      data: [
        {
          tag: 'parse',
          data: [
            {tag: 'atom', data: 'fisticuffs'},
            {
              tag: 'alt',
              data: [
                {tag: 'atom', data: 'twinge'},
                {tag: 'atom', data: 'nevermore'}
              ]
            }
          ]
        }
      ]

    it 'throws an error', ->
      assert.throws (-> boot.refCheck data), ReferenceError
    it 'includes the names of unreferenced rules', ->
      assert.throws (-> boot.refCheck data), /twinge/
      assert.throws (-> boot.refCheck data), /nevermore/
  it 'partitions parse and compile rules', ->
    rules = [p1,c1,p2,c2] =  [
      {tag: 'parse',
      data: [{tag: 'atom', data: 'a'},{tag: 'atom', data: 'b'}]},
      {tag: 'compile',
      data: [{tag: 'atom', data: 'a'}, {tag: 'code', data: 'ugh'}]},
      {tag: 'parse',
      data: [{tag: 'atom', data: 'b'},{tag: 'atom', data: 'a'}]},
      {tag: 'compile',
      data: [{tag: 'atom', data: 'b'}, {tag: 'code', data: 'blugh'}]}
    ]

    data = {tag: 'document', data: rules}
    assert.deepEqual boot.refCheck(data).data, [p1,p2,c1,c2]


describe 'direct left-recursion', ->
  it 'works', ->
    prog = """
      num <- [0-9]+ num -> return Number($);
      main sum <- sum -'+' num | num
      sum -> return $.reduce(function(a,b) {return a + b;});
    """
    sum = boot.eval(prog).val[0]
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
    sum = boot.eval(prog).val[0]
    assert.equal 10, sum('0+1+2+3+4').val[0]

describe 'the frontend', ->
  it 'is implemented correctly', ->
    front = build.src('lib/grammar.shimmre')
    fshim = boot.eval(front.toString()).val[0]
    res = fshim 'main a <- b'
    assert res
    assert res.rem is ''


