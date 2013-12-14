fs = require 'fs'
boot = require './shimmre.js'
assert = require 'assert'

require('./test_shimmre').test 'the bootstrapper', boot.compile

describe 'preprocessing', ->
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
      assert.throws (-> boot.preprocess data), ReferenceError
    it 'includes the names of unreferenced rules', ->
      assert.throws (-> boot.preprocess data), /twinge/
      assert.throws (-> boot.preprocess data), /nevermore/
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
    assert.deepEqual boot.preprocess(data).data, [p1,p2,c1,c2]


