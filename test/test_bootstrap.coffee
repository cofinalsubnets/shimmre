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
        tag: 'parse'
        data: [
          {tag: 'atom', data: 'fisticuffs'}
          tag: 'alt'
          data: [
            {tag: 'atom', data: 'nevermore'}
            {tag: 'atom', data: 'thingy'}
          ]
        ]
      ]

    it 'throws an error', ->
      assert.throws (-> boot.postprocess.refCheck data), ReferenceError
    it 'includes the names of unreferenced rules', ->
      assert.throws (-> boot.postprocess.refCheck data), /thingy/
      assert.throws (-> boot.postprocess.refCheck data), /nevermore/

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
    assert.deepEqual boot.postprocess.refCheck(data).data, [p1,p2,c1,c2]



describe 'the metagrammar', ->
  it 'accepts itself', ->
    front = build.src('lib/grammar.shimmre').toString()
    fshim = boot.eval(front).val[0]
    res = fshim front
    assert res
    assert res.rem is ''

