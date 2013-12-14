assert = require 'assert'

output = (sh, input) -> sh(input).val[0]

exports.test = (doc, shim) ->
  shimmre = (prog, i) -> output(output(shim, prog), i)

  accepts = (prog, i) ->
    out1 = shim(prog)
    if out1 and out1.rem is ''
      out2 = out1.val[0] i
      out2 and out2.rem is ''

  describe "in #{doc}", ->
    describe 'output', ->
      it 'is empty when no main rule is given', ->
        assert.equal undefined, output(shim, 'a <- "b"')
      it 'is present when a main rule is given', ->
        assert output(shim, 'main a <- "b"')

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
        assert not accepts(p, 'optopt')
        assert not accepts(p, 'nopt')

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

    describe 'not-predicate', ->
      it 'works', ->
        p = 'main a <- !"b" [bc]'
        assert accepts(p, 'c')
        assert not accepts(p, 'b')

    describe 'and-predicate', ->
      it 'works', ->
        p = 'main a <- &"b" [bc]'
        assert accepts(p, 'b')
        assert not accepts(p, 'c')

    describe 'a semantic predicate', ->
      it 'works', ->
        p = 'main a <- @b b <- [a-z]+ b -> return $[0] != "x"'
        assert accepts(p, 'abc')
        assert not accepts(p, 'x')
    
    describe 'a comment', ->
      it 'is ignored until the end of the line', ->
        p = """
        main a <- "minnesota"   ; cold in winter
                | "florida"     ; hot in summer
                | "nova scotia" ; canadian
               ;| "belgium"     ; home of the flemish
        """
        for place in ["minnesota", "florida", "nova scotia"]
          assert accepts(p, place)
        assert not accepts(p, "belgium")

    describe 'a duplicate compile rule', ->
      it 'is composed', ->
        p = """
        main a <- "1"
        a -> return Number($[0]);
        a -> return $[0] * 2;
        """
        assert.equal shimmre(p, '1'), 2



