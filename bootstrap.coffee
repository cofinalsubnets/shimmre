match = (v,r) -> {val: v, rem: r}

peg =
  term: (t) -> (str) ->
    str.substr(0, t.length) is t and match([t], str[t.length..])
  cat: (p1, p2) -> (str) ->
    (t1 = p1 str) and (t2 = p2 t1.rem) and match(t1.val.concat(t2.val), t2.rem)
  alt: (p1, p2) -> (str) -> p1(str) or p2 str
  opt: (p) -> (str) -> p(str) or match([], str)
  rep: (p) -> (s) ->
    (r = p s) and map(peg.rep(p), (a) -> r.val.concat a)(r.rem) or match([], s)
  andp: (p) -> (str) -> p(str) and match([], str)
  notp: (p) -> (str) -> not p(str) and match([], str)

# helpers
cat = (ms...) -> ms.reduce peg.cat
alt = (ms...) -> ms.reduce peg.alt
string = peg.term
cheat = (re) -> (s) -> (r = s.match re) and match [r[0]], s[r[0].length..]
_  = cheat /^[\s]*/
__ = cheat /^[\s]+/
nth = (ns...) -> (v) -> v[n] for n in ns
pluck = (v) -> v[0]
sepBy = (p, sep) -> cat p, peg.rep cat(map(sep, ->[]), p)

map = (fn, mfns...) -> (str) ->
  (r = fn str) and match(mfns.reduce(((d,f) -> f d), r.val), r.rem)
tag = (t) -> (d) -> [{tag: t, data: d}]
notp = (p1, p2) -> peg.cat peg.notp(p1), p2

# bootstrapping parser -- grammar -> parse tree
atom = map cheat(/^[a-zA-Z_][a-zA-Z0-9_'-]*/), pluck, tag 'atom'
term = map cheat(/^("(\\"|[^"])*"|'(\\'|[^'])*')/), pluck, ((n) -> n[1..-2]),
  tag 'term'

exp0 = (s) -> alt(notp(ruleInit, atom), term, charopt, paren) s
ruleInit = alt cat(peg.opt(cat(string("main"), __)), atom, _, string '<-'),
  cat(atom, _, string '->')

[repP, optP, plus] = for [s,t] in [['*','rep'],['?','opt'],['+','plus']]
  map cat(exp0, _, string s), nth(0), pluck, tag t
exp1 = alt repP, optP, plus, exp0

[notP, andP, drop] = for [s,t] in [['!','not'],['&','and'],['-','drop']]
  map cat(string(s), _, exp1), nth(2), pluck, tag t
exp2  = map sepBy(alt(notP, andP, drop, exp1), __), tag 'cat'

exp3  = (s) -> map(sepBy(exp2, cat(_, string('|'), _)), tag 'alt') s
paren = map cat(string('('), _, exp3, _, string ')'), nth(2)
charopt = map cheat(/^\[(\\]|[^\]])*\]/), pluck, tag 'charopt'

subPRule = map cat(atom, _, string('<-'), _, exp3), nth(0,4), tag 'parse'
mainPRule = map cat(string("main"), __, subPRule), nth(2), pluck, tag 'main'
pRule = alt mainPRule, subPRule

code = map cheat(/^(.|\n(?=\s))*/), tag 'code'
cRule = map cat(atom, _, string('->'), _, code), nth(0,4), tag 'compile'
rule = alt pRule, cRule
exports.parse = map cat(sepBy(rule, _), map(_, ->[])), tag('document'), pluck

# bootstrapping compiler -- parse tree -> function
class Compile
  constructor: ->
    @rules = {}; @context = {rules: @rules}

  _compile: (d) ->
    unless d.tag of this
      throw new TypeError "Don't know how to compile #{d.tag}"
    this[d.tag] d.data

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

  main: (r) ->
    @_compile r
    _rs = @rules
    @output = (s) -> _rs[r.data[0].data] s

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

  plus: (r) -> @cat [r, {tag: 'rep', data: r}]
  cat: (rs) -> cat.apply this, rs.map(@_compile, this)
  alt: (rs) -> alt.apply this, rs.map(@_compile, this)
  term: peg.term
  rep: (r) -> peg.rep @_compile r
  opt: (r) -> peg.opt @_compile r
  charopt: (c) -> cheat RegExp "^#{c}"
  parse: (r) -> @rules[r[0].data] = @_compile r[1]
  atom:  (a) -> _rs = @rules; (s) -> _rs[a] s
  not:   (n) -> peg.notp @_compile n
  and:   (n) -> peg.andp @_compile n
  drop:  (n) -> map @_compile(n), ->[]

exports.compile = (s) ->
  if not _res = exports.parse s
    throw new SyntaxError "Parse failed at start of input"
  else if _res.rem isnt ''
    throw new SyntaxError "Parse failed:\n#{_res.rem[..70]} ...\n^"
  else
    (c = new Compile())._compile _res.val; c.output

