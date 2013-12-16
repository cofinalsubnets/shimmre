# shimmre

This is an implementation of the shimmre/js metalanguage. Shimmre is a language
for building parsing expression grammar (PEG) parsers and applying
transformations (written in shimmre's host language) to patterns matched by
those parsers. It draws heavily from [OMeta][War09] for instruction and
inspiration, and has several design goals:

- easy porting to new host languages;
- code compatibility between host languages - in particular, shimmre grammars
  are intended to be _completely_ compatible;
- separation of syntax-related code semantics-related code within a shimmre
  program;
- a minimal grammar and runtime environment that makes it easy to implement
  shimmre in shimmre;
- a small and thoroughly documented codebase.

Shimmre/js is 'self-hosting' in the sense that a shimmre/js program defining
shimmre's grammar and transformation rules exists. Since the transformation
rules in a shimmre program are written in the host language, shimmre/js still
requires a JavaScript runtime.

This version of shimmre uses a four-stage process to compile and/or execute
a shimmre program:

1. Preprocessing: text -> text
2. Parsing: text -> AST
3. Postprocessing: AST -> AST
4. Compilation: AST -> output

Shimmre has no purpose-made preprocessor and the code below defaults to using
the identity function. The behavior of each stage can be overridden by injecting
new dependencies, however.

## Parsing shimmre

Parsing expressions in shimmre/js are implemented as functions from strings to
false-ish values (e.g. `false`, `null`) if the parse fails entirely, or to
'match' values containing the parsed value and the remaining input if the
parse partially or completely succeeds:

    match = (v, r) -> {val: v, rem: r}

Whether a parsing expression that matches an input has 'succeeded' depends on
context. For example, a toplevel parser implementing the grammar for a
programming language that returns a match with unconsumed input has probably
encountered a syntax error.

In the future or in alternate implementations, 'match' values may be extended to
contain additional metadata, e.g. for use in error messages.

### Parsing expression functions

    peg =

All of shimmre's PEG primitives return and operate on lists. This provides a
natural way of combining and parse results and expressing 'null' values.

A parsing expression can be created from a terminal string. The value returned
by the expression is the string itself.

      term: (t) -> (str) ->
        match([t], str[t.length..]) if str.substr(0, t.length) is t

Two expressions can be sequenced (_cat_enated). The resulting expression matches
both operands in order, and returns the concatenation of the values of its
operands.

      cat: (p1, p2) -> (str) -> (t1 = p1 str) and
        (t2 = p2 t1.rem) and match(t1.val.concat(t2.val), t2.rem)

Ordered choice (_alt_ernation) between to expressions returns an expression that
matches one operand in order.

      alt: (p1, p2) -> (str) -> p1(str) or p2(str)

Optional expressions are matched zero or one times.

      opt: (p) -> (str) -> p(str) or match([], str)

Repeated expressions are matched zero or more times.

      rep: (p) -> (s) ->
        v = []
        while r = p s
          v = v.concat r.val
          s = r.rem
        match v, s

And-predicates are expressions matched against by the grammar, but have no value
and consume no input when they succeed:

      andp: (p) -> (str) -> match([], str) if p(str)

Not-predicates are anti-matched, have no value, and consume no input:

      notp: (p) -> (str) -> match([], str) unless p(str)

### Convenience functions

    string = peg.term
    cat = (ms...) -> ms.reduce peg.cat
    alt = (ms...) -> ms.reduce peg.alt
    notp = (p1, p2) -> peg.cat peg.notp(p1), p2
    sepBy = (p, sep) -> cat p, peg.rep cat(map(sep, ->[]), p)
    cheat = (re) -> (s) -> (r = s.match re) and match [r[0]], s[r[0].length..]

### Transformation functions

`map` 'maps' transformation functions across a parsing expression. The result
is a new parsing expression that, when successful, threads its value through the
transformations in the order they were supplied to `map`.

    map = (fn, mfns...) -> (str) ->
      (r = fn str) and match(mfns.reduce(((d,f) -> f d), r.val), r.rem)

The tags applied by `tag` are used later by the compiler.

    tag = (t) -> (d) -> [{tag: t, data: d}]
    nth = (ns...) -> (v) -> v[n] for n in ns
    pluck = (v) -> v[0]

### The parser

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
'drop' (`-`) and semantic-predicate (`@`) prefix operators. A 'dropped'
expression is still a part of the grammar and consumes input on a successful
match, but the value of the match (if any) is discarded. A semantic predicate
matches if its operand matches, and if its operand's output is true-ish.

    prefixes = [['!','not'],['&','and'],['-','drop'],['@','semantic']]
    [notP, andP, drop, semP] = for [s,t] in prefixes
      map cat(string(s), _, exp1), nth(2), pluck, tag t
    exp2  = map sepBy(alt(notP, andP, drop, semP, exp1), __), tag 'cat'

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
    parse = map cat(map(_, ->[]), sepBy(rule, _), map(_, ->[])),
      tag('document'), pluck

    exports.parse = parse

## Postprocessing

After a document has been parsed, subsequent operations involve examining and
transforming the document's abstract syntax tree.

    class ASTVisitor
      visit: (node) -> this[node.tag](node.data, node) if node.tag of this
      walk: (node) ->
        @visit node
        @walk n for n in node.data if Array.isArray node.data

Shimmre first simplifies the tree by eliminating unnecessary `alt` and `cat`
nodes. `liftNode` replaces nodes with only one child with the child node:

    liftNode = (node) ->
      while Array.isArray(node.data) and node.data.length is 1
        [node.tag, node.data] = [node.data[0].tag, node.data[0].data]

When `liftNode` returns, its argument has either zero children or multiple
children.

`mergeNode` merges the children of a node with the same type as its parent back
into the parent node. For example, `Cat [Cat [x, y], z]` becomes
`Cat [x, y, z]`.

    mergeNode = (node) ->
      if Array.isArray node.data
        loop
          contents = []; diff = false
          for n in node.data
            if n.tag is node.tag
              contents = contents.concat n.data
              diff = true
            else contents.push n
          if diff then node.data = contents else break

When `mergeNode` returns, its argument has no children of the same type as
itself.

Since (subject to the assumption enforced by the parser that no `alt` or `cat`
node is empty) `mergeNode` can never decrease the number of children of its
argument, and `liftNode` can only optimize a node with exactly one child, we run
no risk of leaving the node in an unoptimized state if we call `liftNode` and
`mergeNode` in order.

    scrubNode = (node) ->
      liftNode node
      mergeNode node

    class ASTCleanup extends ASTVisitor
      cat: (data, node) -> scrubNode node
      alt: (data, node) -> scrubNode node

    cleanup = (ast) -> new ASTCleanup().walk ast; ast

Shimmre then verifies that all referenced rules are defined, and partitions
parse and compile rules (ensuring that compile rules come after their associated
parse rules makes the next step easier).

    class BaseRefChecker extends ASTVisitor
      constructor: (@refdata) ->

    class RRefChecker extends BaseRefChecker
      atom: (name) -> @refdata.rvals[name] = true

    class RefChecker extends BaseRefChecker
      document: (rules) -> @visit r for r in rules
      main: (body, rule) ->
        @refdata.rules['parse'].push rule
        @refdata.lvals['parse'][body.data[0].data] = true
        new RRefChecker(@refdata).walk body
      parse: (body, rule) ->
        @_rule rule
        new RRefChecker(@refdata).walk body[1]
      compile: (body, rule) -> @_rule rule
      _rule: (rule) ->
        @refdata.rules[rule.tag].push rule
        @refdata.lvals[rule.tag][rule.data[0].data] = true

    class RefData
      constructor: (doc) ->
        @lvals = {parse: {}, compile: {}}
        @rvals = {}
        @rules = {parse: [], compile: []}
        new RefChecker(this).visit doc

    refCheck = (doc) ->
      rd = new RefData doc

      if (r = (v for v of rd.rvals when v not of rd.lvals.parse)).length
        throw new ReferenceError(
          "Can't resolve invoked parsing expression(s): #{r.join ', '}")

      if (r = (v for v of rd.lvals.compile when v not of rd.lvals.parse)).length
        throw new ReferenceError("Orphan compile rule(s): #{r.join ', '}")

      doc.data = rd.rules.parse.concat rd.rules.compile
      doc

Finally, shimmre makes sure that exactly one main rule was supplied.

    mainCheck = (doc) ->
      switch doc.data.filter((t) -> t.tag is 'main').length
        when 0 then throw new SyntaxError("No main rule found")
        when 1 then return doc
        else throw new SyntaxError("Multiple main rules found")

    postprocess = (doc) -> mainCheck refCheck cleanup doc
    postprocess.cleanup = cleanup
    postprocess.refCheck = refCheck
    postprocess.mainCheck = mainCheck

    exports.postprocess = postprocess

## Compilation

### Packrat parsing and left-recursion

By default shimmre generates [packrat parsers][For02]. Packrat parsing  offers
two main benefits:

- The avoidance of potentially exponential parse time due to backtracking, since
  no parse rule is evaluated more than once at a given position in the input.
  Obviously this comes at the cost of greater memory use, and on certain inputs
  (those that cause little or no backtracking) packrat parsers will be _slower_
  than equivalent non-memoizing parsers.

- More interestingly, by using a technique developed for OMeta, packrat parsing
  allows parsing expression grammars to negotiate left-recursive parse rules.

Shimmre's packrat parsing implementation uses a variation on OMeta's algorithm
to resolve directly and indirectly left-recursive rules. In short, it
identifies left-recursions by pre-memoizing a special sentinel value and then
progressively growing the parse result in a way that avoids an infinite loop.
Accomodating indirect left-recursion also requires imposing additional checks
on the memoization of intermediate rules. For more information, see the
aforelinked paper on OMeta and [this blog post][Jel13].

    class LR
    NOMEMO = new Object()

    growLR = (fn, d, memo) ->
      rem = memo[d].rem
      while rem and (res = fn d) and res.rem.length < rem.length
        rem = res.rem
        memo[d] = res

    memoize = (fn) -> memo = {}; (d) ->
      if memo.hasOwnProperty d
        if memo[d] is NOMEMO          then return fn d
        else if memo[d] instanceof LR then throw memo[d]
        else                               return memo[d]
      else
        memo[d] = new LR()
        try memo[d] = fn d
        catch e
          throw e unless e instanceof LR
          if e is memo[d]
            memo[d] = false
            if memo[d] = fn d then growLR(fn, d, memo)
          else
            memo[d] = NOMEMO
            throw e
        memo[d]

### Backends and compilation targets

A backend is a function from a parse tree to some kind of output. We implement
backends using a variation on the visitor class we've already defined:

    class Backend extends ASTVisitor
      constructor: (@packrat) -> @rules = {}; @context = {}
      document: (rs) -> @visit r for r in rs

    backend = (visitor) -> (doc) ->
      (v = new visitor(true)).visit doc; v.output

Two backends to the shimmre compiler are provided. The first evaluates the
shimmre code directly and returns a JavaScript function object implementing the
shimmre program. The second compiles shimmre to stand-alone JavaScript. Both use
the same basic mechanism to walk the AST and register their output.

#### The "eval" backend

    class Eval extends Backend
      document: (rs) ->
        super
        if @packrat
          @rules[r] = memoize @rules[r] for r of @rules

The main rule is stored under the Compile object's `output` attribute.

      main: (r) ->
        @visit r
        @output = ((s) -> @rules[r.data[0].data] s).bind this

Parse rules store their compiled values under the Compile object's `rules`
attribute. If multiple definitions for one rule exists, they are combined
using ordered choice.

      parse: ([{data}, body]) ->
        @rules[data] =
          if data of @rules
            peg.alt @rules[data], @visit body
          else
            @visit body

Compile rules have their code blocks turned into JavaScript functions, and the
resulting transformation function is `map`ped over the parse rule of the same
name. Within the body of a compile rule, the parse rule's output is accessible
through the `$` array argument. Judicious use of the drop operator ensures that
the programmer won't have to deal with any unneeded results.

      compile: ([{data: name}, {data: code}]) ->
        tfn = new Function('$', code)
        transform = (argv) ->
          if (x = tfn.call @context, argv)? then [x] else []
        @rules[name] = map @rules[name], transform.bind(this)

References to other rules are late-bound to permit recursive and out-of-order
definitions, and so that all references end up pointing to the rule in its
final state. The preprocessing phase ensures that all of these references will
ultimately succeed.

      atom:  (a) -> ((s) -> @rules[a] s).bind this

Parsing expression generation rules straightforwardly invoke functions defined
earlier.

      term: peg.term
      plus: (r) -> @cat [r, {tag: 'rep', data: r}]
      cat: (rs) -> cat.apply this, rs.map(@visit, this)
      alt: (rs) -> alt.apply this, rs.map(@visit, this)
      rep:  (r) -> peg.rep @visit r
      opt:  (r) -> peg.opt @visit r
      not:  (n) -> peg.notp @visit n
      and:  (n) -> peg.andp @visit n
      drop: (n) -> map @visit(n), ->[]
      charopt:  (c) -> cheat RegExp "^#{c}"
      semantic: (n) ->
        _match = @visit n
        (s) -> (_res = _match s) and _res.val[0] and _res

    evalBackend = backend Eval

#### The JavaScript backend

The JavaScript compiler can mostly be implemented using existing code.

    BASEDEFS = """
      #{("var #{p} = #{peg[p].toString()};" for p of peg).join('\n')}
      var map = function (a, b) {
        return function (s) {
          var res = a(s);
          return res && match(b(res.val), res.rem);
        };
      };
      var match = #{match.toString()};
      var cheat = #{cheat.toString()};
      var drop = function () {return [];};
      var merge = function (v) {
        return (v===null || v===undefined) ? [] : Array.isArray(v) ? v : [v];
      };
      var semp = function (f) {
        return function (s) {
          var res = f(s);
          if (res && res.val[0])
            return res;
          else return false;
        };
      };
    """

    MEMODEFS = """
      var LR = function () {};
      var NOMEMO = new Object();
      var memoize = #{memoize.toString()};
      var growLR = #{growLR.toString()};
      for (var k in rules)
        rules[k] = memoize(rules[k]);
    """

    dottable = (s) -> s.match /^[a-zA-Z_]\w*$/
    exports.memoize = memoize

The JS compiler's toplevel assembles a piece of JavaScript code that, when
evaluated, returns the desired parsing function. Its functioning is otherwise
directly analogous to the eval backend.

    class JavaScript extends Backend
      document: (rs) ->
        super
        ruledefs = for a of @rules
          "#{JSON.stringify a} : function (s) {return #{@rules[a]}(s);}"
        @output = """
          (function () {
            #{BASEDEFS}
            var rules = { #{ruledefs.join ',\n'} }; 
            #{MEMODEFS if @packrat}
            return function (s) { return #{@atom @_main}(s); };
          }).call(this)
        """

      main: (r) -> @visit r; @_main = r.data[0].data

      parse: ([{data}, body]) ->
        @rules[data] =
          if data of @rules
            "alt(#{@rules[data]},#{@visit body})"
          else
            @visit body

      compile: ([{data: name}, {data: code}]) ->
        tfn = "function ($) {#{code}}"
        @rules[name] = "map(map(#{@rules[name]},#{tfn}),merge)"

      atom: (a) -> "rules" +
        if dottable a then "." + a else "[#{JSON.stringify a}]"
      plus: (r) -> @cat [r, {tag: 'rep', data: r}]
      cat: (rs) -> rs.map(@visit, this).reduce (c, n) -> "cat(#{c},#{n})"
      alt: (rs) -> rs.map(@visit, this).reduce (c, n) -> "alt(#{c},#{n})"
      term: (s) -> "term(#{JSON.stringify s})"
      rep:  (r) -> "rep(#{@visit r})"
      opt:  (r) -> "opt(#{@visit r})"
      not:  (n) -> "notp(#{@visit n})"
      and:  (n) -> "andp(#{@visit n})"
      drop: (n) -> "map(#{@visit n},drop)"
      semantic: (n) -> "semp(#{@visit n})"
      charopt:  (c) -> "cheat(RegExp('^'+#{JSON.stringify c}))"

    jsBackend = backend JavaScript
      
## Tying it all together

The entire compilation pipeline comes down to this:

    class Compiler
      constructor: (@pre, @front, @post, @back) ->

For compatibility and composability, instances of `Compiler` return output
wrapped in an array and a `match` result. This means that compilers have
identical outward semantics to regular matching functions defined using the PEG
primitives, and a compiler supporting multiple (hypothetical) shimmre dialects
could be created simply by `alt`ing together a compiler for each one.

      compile: (d) -> map(@front, @post, @back, (n) -> [n]) @pre d

    Compiler.Default = Compiler.bind(null, ((n) -> n), parse, postprocess)

    evaluator  = new Compiler.Default evalBackend
    jsCompiler = new Compiler.Default jsBackend

    exports.Compiler = Compiler
    exports.eval    = (d) -> evaluator.compile d
    exports.compile = (d) -> jsCompiler.compile d

## Future directions

One intriguing possibility might be to extend shimmre to operate over arbitrary
sequential data, rather than just strings. The necessary modifications are
very small, and providing a rule composition operator would make it easy for
shimmre to traverse nested as well as flat sequences. We could then (for
example) rewrite the postprocessing routine given in this document in shimmre
itself.

I've actually tried this, and found that while shimmre ably handles _traversal_
of arbitrary serial data, the amount of host language code required to actually
do anything means that there's little benefit to using shimmre over a pure host
language solution. It might make sense if the host language were sorely lacking
in convenient primitives for dealing with sequences, but then implementing
shimmre in the first place would be difficult. Furthermore, the use of packrat
parsing impacts many use cases for shimmre as a "visitor generator" - for
example, when shimmre is expected to execute side effects on each encounter with
a certain subsequence.

In short, shimmre makes a decent parser - and the point of a parser is to impose
structure on _unstructured_ data. That said, there may be a middle ground where
a tool like shimmre can still be useful, like as an runtime "typechecker" that
ensures an object implements a certain interface, or even as the basis for a
testing framework where the desired properties of a datum are defined as a
"grammar" according to which shimmre will accept or reject a test case -
more generally, cases where the main concern is for verifying the structure of
data, rather than interpreting or transforming its content. A few somewhat
host-dependent but still fairly abstract syntactic extensions, like a
generalized "field access" operator for example, would make writing this kind of
program more pleasant.

##  That's it!

Thanks for reading this far! For examples of actual shimmre code, see the other
files under `lib` in this repository.

[For02]: http://pdos.csail.mit.edu/~baford/packrat/thesis/thesis.pdf
[War09]: http://www.vpri.org/pdf/tr2008003_experimenting.pdf
[Jel13]: http://walpurgisriot.github.io/blog/2013/12/13/indirect-left-recursion-in-packrat-parsers.html

