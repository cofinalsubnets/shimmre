fs = require 'fs'
assert = require 'assert'
boot = require '../bootstrap.coffee'
shimmreSrc = fs.readFileSync 'shimmre.shimmre', 'utf8'
jscSrc = fs.readFileSync 'jsc.shimmre', 'utf8'

output = (sh, input) ->
  assert (out = sh input)
  assert.equal '', out.rem
  out.val[0]

jsc = output boot.compile, jscSrc

shims = [
  ['the bootstrapper', boot.compile],
  ['a self-hosted shimmre', output(boot.compile, shimmreSrc)],
  ['a compiled-to-js shimmre', eval output(jsc, shimmreSrc)]
]

for [doc,shim] in shims
  shimmre = (prog, i) -> output(output(shim, prog), i)

  accepts = (prog, i) ->
    try
      shimmre(prog, i)
      true
    catch e
      false

  describe "in #{doc}", ->
    describe 'output', ->
      it 'is empty when no main rule is given', ->
        assert.equal undefined, output(shim, 'a <- b')
      it 'is present when a main rule is given', ->
        assert output(shim, 'main a <- b')

    describe 'sequencing', ->
      it "works", ->
        seqs = [
          ['main a <- "a" "b"', 'ab'],
          ['main a <- b c b <- "hi" " " c <- "there"', 'hi there']
        ]
        for [p,i] in seqs
          assert shimmre(p,i)

    describe 'choice', ->
      it "is ordered", ->
        prog = 'main a <- b | c b <- "a" c <- "a" b -> return 1\nc -> return 2'
        assert.equal 1, shimmre(prog, 'a')
      it "works", ->
        greetings = ["hi", "hello", "salutations"]
        prog = 'main a <- "hi" | "hello" | "salutations"'
        assert shimmre(prog, g) for g in greetings

    describe 'option', ->
      it 'takes zero or one of its argument', ->
        p = 'main a <- "opt"?'
        assert accepts(p, '')
        assert accepts(p, 'opt')

    describe 'repetition', ->
      it 'takes zero or more of its argument', ->
        p = 'main a <- "a"*'
        assert accepts(p, '')
        assert accepts(p, 'a')
        assert accepts(p, 'aaaaaaaaaaaaaaaa')
        assert not accepts(p, 'b')

    describe 'one-or-more', ->
      it 'works', ->
        p = 'main a <- "b"+'
        assert accepts(p, 'b')
        assert accepts(p, 'bbbbbbbbbbbb')
        assert not accepts(p, '')

    describe 'a compile rule', ->
      it 'transforms its input', ->
        p = 'main a <- "b" a -> return "c"'
        assert.equal shimmre(p, 'b'), 'c'

    describe 'a character range', ->
      it 'works like a regex', ->
        p = 'main a <- [abc] [123]'
        for l in ['a', 'b', 'c']
          for n in ['1', '2', '3']
            assert accepts(p, l+n)
      describe 'negated', ->
        it 'works like a regex', ->
          p = 'main a <- [^asdf]'
          assert accepts(p, 'b')
          assert not accepts(p, 'd')

