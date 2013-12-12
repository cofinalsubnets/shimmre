shimmre
=======

This is the bootstrap implementation of the shimmre/JS metalanguage. Shimmre is
a language for building parsing expression grammar (PEG) parsers and applying
transformations (written in shimmre's host language) to patterns matched by
those parsers.

Shimmre is self-hosting in the sense that a shimmre/JS program defining
shimmre's grammar and transformation rules exists. Since the transformation
rules in a shimmre program are written in the host language, shimmre/JS still
requires a JavaScript runtime.

Parsing expressions in shimmre are implemented as functions from strings to
false-ish values (e.g. `false`, `null`) if the parse fails entirely, or to
'match' values containing the parsed value and the remaining input if the
parse partially or completely succeeds:

    match = (v, r) -> {val: v, rem: r}

A parsing expression that returns a match has not necessarily succeeded; for
example, a toplevel parser implementing a programming language that returns
a match with unconsumed input has probably encountered a syntax error.

In the future or in alternate implementations, 'match' values may be extended to
contain additional metadata, e.g. for use in error messages.

Parsing expression functions
----------------------------

    peg =

All of shimmre's PEG primitives return and operate on lists. This provides a
natural way of combining and parse results and expressing 'null' values.

A parsing expression can be created from a terminal string. The value returned
by the expression is the string itself.

      term: (t) -> (str) ->
        str.substr(0, t.length) is t and match([t], str[t.length..])

Two expressions can be sequenced (_cat_enated). The resulting expression matches
both operands in order, and returns the concatenation of the values of its
operands.

      cat: (p1, p2) -> (str) -> (t1 = p1 str) and
        (t2 = p2 t1.rem) and match(t1.val.concat(t2.val), t2.rem)

Ordered choice (_alt_ernation) between to expressions returns an expression that
matches one operand in order.

      alt: (p1, p2) -> (str) -> p1(str) or p2 str

Optional expressions are matched zero or one times.

      opt: (p) -> (str) -> p(str) or match([], str)

Repeated expressions are matched zero or more times.

      rep: (p) -> (s) -> (r = p s) and
        map(peg.rep(p), (a) -> r.val.concat a)(r.rem) or match([], s)

And-predicates are expressions matched against by the grammar, but have no value
and consume no input when they succeed:

      andp: (p) -> (str) -> p(str) and match([], str)

Not-predicates are anti-matched, have no value, and consume no input:

      notp: (p) -> (str) -> not p(str) and match([], str)

Convenience functions
---------------------

    string = peg.term
    cat = (ms...) -> ms.reduce peg.cat
    alt = (ms...) -> ms.reduce peg.alt
    notp = (p1, p2) -> peg.cat peg.notp(p1), p2
    sepBy = (p, sep) -> cat p, peg.rep cat(map(sep, ->[]), p)
    cheat = (re) -> (s) -> (r = s.match re) and match [r[0]], s[r[0].length..]

Transformation functions
------------------------

`map` 'maps' transformation functions across a parsing expression. The result
is a new parsing expression that, when successful, threads its value through the
transformations in the order they were supplied to `map`.

    map = (fn, mfns...) -> (str) ->
      (r = fn str) and match(mfns.reduce(((d,f) -> f d), r.val), r.rem)

The tags applied by `tag` are used later by the compiler.

    tag = (t) -> (d) -> [{tag: t, data: d}]
    nth = (ns...) -> (v) -> v[n] for n in ns
    pluck = (v) -> v[0]

Parsing shimmre
---------------

Unlike the shimmre/JS self-implementation, the bootstrap shimmre uses a
two-stage parse/compile process to interpret a shimmre program. The parse stage
constructs an AST from the shimmre source code.

With one important exception, whitespace is significant in shimmre only as a
token separator. Comments in shimmre start with a semicolon and continue to the
end of the line. Shimmre currently has no syntax for block comments.

    _  = cheat /^(\s|;.*)*/
    __ = cheat /^(\s|;.*)+/

An atom is a bare word used by shimmre as a rule identifier.

    atom = map cheat(/^[a-zA-Z_][a-zA-Z0-9_'-]*/), pluck, tag 'atom'

Strings may be delimited by double- or single-quotes and represent terminal
rules.

    term = map cheat(/^("(\\"|[^"])*"|'(\\'|[^'])*')/),
      pluck, ((n) -> n[1..-2]), tag 'term'

Operator precedence in shimmre is: postfix > prefix > sequence > choice.
Parentheses can be used for grouping.

    exp0 = (s) -> alt(notp(ruleInit, atom), term, charopt, paren) s
    ruleInit = alt cat(peg.opt(cat(string("main"), __)), atom, _, string '<-'),
      cat(atom, _, string '->')

In addition to repetition (`*`) and option (`?`), shimmre supports a one-or-more
postfix operator (`+`).

    [repP, optP, plus] = for [s,t] in [['*','rep'],['?','opt'],['+','plus']]
      map cat(exp0, _, string s), nth(0), pluck, tag t
    exp1 = alt repP, optP, plus, exp0

In addition to not-predicate (`!`) and and-predicate (`&`), shimmre supports a
'drop' prefix operator (`-`). A 'dropped' expression is still a part of the
grammar and consumes input on a successful match, but the value of the match
(if any) is discarded.

    [notP, andP, drop] = for [s,t] in [['!','not'],['&','and'],['-','drop']]
      map cat(string(s), _, exp1), nth(2), pluck, tag t
    exp2  = map sepBy(alt(notP, andP, drop, exp1), __), tag 'cat'

Choice (`|`) is the 'toplevel' expression.

    exp3  = (s) -> map(sepBy(exp2, cat(_, string('|'), _)), tag 'alt') s
    paren = map cat(string('('), _, exp3, _, string ')'), nth(2)

Shimmre recognizes regex-like bracket expressions such as `[0-9]` and
`[aeiouy]`.

    charopt = map cheat(/^\[(\\]|[^\]])*\]/), pluck, tag 'charopt'

Shimmre rules are either 'parse' rules, which describe a grammar, or 'compile'
rules, which define transformations on matched values. One parse rule must be
designated as the 'main' rule, which is used as an entry point to the parser.

    subPRule = map cat(atom, _, string('<-'), _, exp3), nth(0,4), tag 'parse'
    mainPRule = map cat(string("main"), __, subPRule), nth(2), pluck, tag 'main'
    pRule = alt mainPRule, subPRule

Compile rules contain blocks of code in the host language. All text from the
beginning of a compile rule to the first line beginning with a non-whitespace
character is treated as code. This is the one aforementioned case where shimmre
is whitespace-sensitive.

    code = map cheat(/^(.|\n(?=\s))*/), tag 'code'
    cRule = map cat(atom, _, string('->'), _, code), nth(0,4), tag 'compile'

A shimmre program consists of a series of rules. Parse rules require no
separator - not even a line break. Compile rules must be newline-separated for
the reason explained above.

    rule = alt pRule, cRule
    exports.parse = map cat(map(_, ->[]), sepBy(rule, _), map(_, ->[])),
      tag('document'), pluck

Interpreting shimmre
--------------------

The 'compile' stage walks the AST generated by the parse stage and returns a
match object.

    class Compile

Code contained in compile rules is evaluated in a shared context, which can be
used to store program state.

      constructor: ->
        @rules = {}
        @context = {}

Data from the AST are dispatched by tag.

      _compile: (d) ->
        unless d.tag of this
          throw new TypeError "Don't know how to compile #{d.tag}"
        this[d.tag] d.data

The toplevel of a shimmre program. Rules are compiled, and the results are
checked for referenced-but-undefined rules. Currently the self-implementation
lacks this feature.

      document: (rs) ->
        @_compile r for r in rs
        unresolved = []
        for r of @rules
          try @rules[r] ''
          catch e
            # FIXME: better solution than regex
            if e instanceof TypeError and m = e.message.match /method '([^']+)/
              unresolved.push m[1]
            else throw e
        if unresolved.length isnt 0
          throw new ReferenceError(
            "Can't resolve parsing expressions: #{unresolved.join ', '}")

The main rule is stored under the Compile object's `output` attribute.

      main: (r) ->
        @_compile r
        _rs = @rules
        @output = (s) -> _rs[r.data[0].data] s

Parse rules store their compiled values under the Compile object's `rules`
attribute.

      parse: (r) -> @rules[r[0].data] = @_compile r[1]

Compile rules have their code `eval`'d into JavaScript functions, and the
consequent transformation function is `map`ped over the parse rule of the
same name. Within the body of a compile rule, the parse rule's output is
accessible through the `$` array argument. Judicious use of the drop operator
ensures that the programmer won't have to deal with any unneeded results.

While parse rules can be defined in any order, currently all shimmre
implementations constrain compile rules to come after their associated parse
rules. There's no reason why this has to be the case - I just haven't written
it yet.

      compile: (r) ->
        [_atm, _code] = r
        # FIXME
        unless _rule = @rules[_atm.data]
          throw new Error(
            "Compile rule `#{_atm.data}' defined before parse rule")
        _tfn = eval "(function ($) {#{_code.data}})"
        _ctx = @context
        _transform = (argv) ->
          x = _tfn.call _ctx, argv
          if x? then Array.isArray(x) and x or [x] else []
        @rules[_atm.data] = map _rule, _transform

Parsing expression generation rules straightforwardly invoke functions defined
earlier.

      plus: (r) -> @cat [r, {tag: 'rep', data: r}]
      cat: (rs) -> cat.apply this, rs.map(@_compile, this)
      alt: (rs) -> alt.apply this, rs.map(@_compile, this)
      term: peg.term
      rep: (r) -> peg.rep @_compile r
      opt: (r) -> peg.opt @_compile r
      charopt: (c) -> cheat RegExp "^#{c}"
      atom:  (a) -> _rs = @rules; (s) -> _rs[a] s
      not:   (n) -> peg.notp @_compile n
      and:   (n) -> peg.andp @_compile n
      drop:  (n) -> map @_compile(n), ->[]

For compatibility and composability, the `compile` function exposed by the
bootstrap shimmre wraps its output in a match object.

    exports.compile = map exports.parse, (pt) ->
      (c = new Compile())._compile pt; [c.output]

