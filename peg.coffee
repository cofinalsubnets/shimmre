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
  andp: (p1) -> (str) -> p1(str) and match([], str)
  notp: (p1) -> (str) -> not p1(str) and match([], str)

# helpers
cat = (ms...) -> ms.reduce peg.cat
alt = (ms...) -> ms.reduce peg.alt
string = peg.term
cheat = (re,n) -> (s) -> (r = s.match re) and match [r[n||0]], s[r[n||0].length..]
_  = cheat /^[\s]*/
__ = cheat /^[\s]+/
nth = (ns...) -> (v) -> v[n] for n in ns
pluck = (v) -> v[0]
sepBy = (p, sep) -> cat p, peg.rep cat(map(sep, ->[]), p)

map = (fn, mfns...) -> (str) ->
  (r = fn str) and match(mfns.reduce(((d,f) -> f d), r.val), r.rem)
tag = (t) -> (d) -> [{tag: t, data: d}]
retag = (t) -> (d) -> d.map (_d) -> {tag: t, data: _d.data}
notp = (p1, p2) -> peg.cat peg.notp(p1), p2

# bootstrapping parser -- grammar -> parse tree
atom = map cheat(/^[a-zA-Z_][a-zA-Z0-9_'-]*/), pluck, tag 'atom'
bound = (mfn) ->
  map cat(mfn, string(':'), atom), ((n) -> n[0].name=n[2].data; [n[0]])
term = map cheat(/^("(\\"|[^"])*"|'(\\'|[^'])*')/), pluck, ((n) -> n[1..-2]),
  tag 'term'

exp0 = (s) -> alt(notp(ruleInit, atom), term, charopt, paren) s
exp1 = alt bound(exp0), exp0
ruleInit = alt cat(peg.opt(cat(string("main"), __)), atom, _, string('<-')),
  cat(atom, _, string '->')

[repP, optP, plus] = for [s,t] in [['*','rep'],['?','opt'],['+','plus']]
  map cat(exp1, _, string s), nth(0), pluck, tag t
[notP, andP] = for [s,t] in [['!','not'],['&','and']]
  map cat(string(s), _, exp1), nth(2), pluck, tag t

exp2  = map sepBy(alt(repP, optP, plus, notP, andP, exp1), __), tag 'cat'
exp3  = (s) -> map(sepBy(exp2, cat(_, string('|'), _)), tag 'alt') s
paren = map cat(string('('), _, exp3, _, string ')'), nth(2)
charopt = map cheat(/^\[(\\]|[^\]])*\]/), pluck, tag 'charopt'

subPRule = map cat(atom, _, string('<-'), _, exp3),
  nth(0,4), tag 'parse_rule'
mainPRule = map cat(string("main"), __, subPRule), nth(2), retag 'main'
pRule = alt mainPRule, subPRule

code = map cheat(/^(.|\n(?=\s))*/), tag 'code'
cRule = map cat(atom, _, string('->'), _, code), nth(0,4), tag 'compile_rule'
rule = alt pRule, cRule
exports.parse = map cat(sepBy(rule, _), map(_, ->[])), tag('document'), pluck
exports.term = term
exports.cheat = cheat

exports.peg = peg
exports.sepBy = sepBy

# bootstrapping compiler -- parse tree -> function

class RuleError
  constructor: (@message) ->
RuleError.prototype = new Error()

contentEq = (a,b) -> a.every((e) -> e in b) and b.every((e) -> e in a)

class Compile
  constructor: ->
    @rules = {}
    @context = {}
    @parsedata = {}

  compile: (d) ->
    unless d.tag of this
      throw new TypeError "Don't know how to compile #{d.tag}"
    this[d.tag] d.data, d.name

  document: (rs) ->
    @compile r for r in rs

    unresolved = []
    for r of @rules
      try
        @rules[r] ''
      catch e
        # FIXME: better solution than regex
        if e instanceof TypeError and m = e.message.match /method '([^']+)/
          unresolved.push m[1]
        else throw e

    if unresolved.length
      throw new ReferenceError(
        "Can't resolve parsing expressions: #{unresolved.join ', '}")

  main: (r) -> @output = @parse_rule r
  plus: (r) -> @compile {tag: 'cat', data: [r, {tag: 'rep', data: r}]}
  cat: (rs) -> cat.apply this, rs.map(@compile, this)
  alt: (rs) -> if rs.length is 1 then @compile rs[0] else
    alt.apply this, rs.map(@compile, this)

  rep: (r) -> peg.rep @compile r
  opt: (r) -> peg.opt @compile r
  term: peg.term
  charopt: (rs) -> cheat RegExp "^#{rs}"

  parse_rule: (r) ->
    @parsedata[r[0].data] ||= r[1]
    @rules[r[0].data] = @compile r[1]

  atom: (a) -> _rs=@rules; (s) -> _rs[a] s
  not: (n) -> peg.notp @compile n
  and: (n) -> peg.andp @compile n

  compile_rule: (r) ->
    [_atm, _code] = r

    # FIXME
    unless _rule = @rules[_atm.data]
      throw new Error(
        "Compile rules must (currently) come after associated parse rules")

    _tfn = eval "(function (#{"$#{n}" for n in [1..9]}) {#{_code.data}})"
    _ctx = @context
    _transform = (argv) -> if (x = (_tfn.apply _ctx, argv))? then [x] else []
    @rules[_atm.data] = map _rule, _transform

exports.compile = (pt) -> (c = new Compile()).compile pt; c
exports.peg = peg

