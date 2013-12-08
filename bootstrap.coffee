# this is the CoffeeScript implementation of the metagrammar parser / compiler.

p = require './helpers.js'
char = require './char.js'

tag = (tag, data) -> {tag: tag, data: data}

atom = p.transform(
  p.cat([p.oneOf(char.alpha+"_"), p.stringOf(char.alphanum + "_-'")]),
  (a) -> tag('atom', a.join ''))

_dq_str = p.delimitedString('"', '"')
_sq_str = p.delimitedString("'", "'")
term = p.transform p.alt([_dq_str, _sq_str]), (n) -> tag('term', n)

ws = p.many p.space

oneExpr = (str) -> p.alt([atom, term, charOpt, parenthetical]) str

rep =  p.transform p.cat([oneExpr, ws, p.string "*"]), (n) -> tag('rep', n[0])
opt =  p.transform p.cat([oneExpr, ws, p.string "?"]), (n) -> tag('opt', n[0])
plus = p.transform p.cat([oneExpr, ws, p.string "+"]), (n) -> tag('plus', n[0])

cexpr = p.transform(
  p.sepBy(p.alt([rep, opt, plus, oneExpr]), p.many1 p.space),
  (xs) -> tag('cat', xs))

aexpr = p.transform(
  p.sepBy(cexpr, p.wrap(p.string("|"), ws)), (as) -> tag('alt', as))

parenthetical = p.transform(
  p.cat([p.string("("), ws, aexpr, ws, p.string(")")]),
  (n) -> n[2])

rangeChar = p.transform(
  p.alt([ p.oneOf(char.all.replace(/]/, '')),
          p.escaped ']']),
  (n) -> tag('char', n))

range = p.transform(
  p.cat([rangeChar, p.string("-"), rangeChar]),
  (n) -> tag('range', [n[0], n[2]]))

optContents = p.many p.alt [range, rangeChar]

charOpt = p.transform p.delimitedString("[", "]"), (n) -> tag('charopt', n)

oneLiner = p.transform p.many(p.cheat /^.(?!$)/), (n) -> "{#{n.join('')}}"

exports.cb = codeBlock = p.transform(
  p.cat([p.many(p.string ' '), p.string("\n"),
         p.many(p.cheat /^(.|\n(?=\s))/)]),
  (n) -> "{#{n[2].join('')}}")


code = p.transform(p.cat([p.string('->'), p.alt([codeBlock, oneLiner])]),
  (n) -> tag('code', n[1]))

rule = p.transform(
  p.cat([ atom, p.string(":="), aexpr,
          p.alt [code, p.transform(p.string(";"), ->)]
        ].map((n)->p.wrap n, ws)),
  (a) -> tag('rule', [a[0],a[2], a[3]]))

contentEq = (a1, a2) -> a1.every((e) -> e in a2) and a2.every((e) -> e in a1)

mainRule = p.transform(
  p.cat([ws, p.string("main"), p.many1(p.space), rule]),
  (n) -> tag('main', n[3]))


parse = p.transform(
  p.sepBy(p.alt([mainRule, rule]), ws), (n) -> tag('document', n))

toplevelParser = (prsr) -> (str) ->
  rslt = prsr str
  if rslt and rslt.rem is ''
    {success: true, val: rslt.val}
  else
    {success: false}

class RuleError
  constructor: (@message) ->

class Compiler
  compile: (d) ->
    @rules = {}
    @context = {}
    @_compile d
    @output or throw new RuleError "No main rule found"

  _compile: (d) ->
    unless d.tag of this
      throw new TypeError "Don't know how to compile #{d.tag}"
    this[d.tag](d.data)

  document: (rules) ->
    lastRules = []
    while rules.length isnt 0
      if contentEq rules, lastRules
        throw new ReferenceError(
          # FIXME: need better feedback here - if rule A won't compile because
          # it references an undefined rule B, then this will complain:
          # > "Can't resolve parsing expressions: A"
          # which is techically true, but suboptimally helpful.
          "Can't resolve parsing expressions: #{
            rules.map (r) -> r.data[0].data.join(', ')}")
      else
        deferred = []
        for rule in rules
          try
            @_compile rule
          catch a
            if a instanceof RuleError then deferred.push rule else throw a
        [rules, lastRules] = [deferred, rules]

  atom: (a) -> @rules[a] or throw new RuleError a
  plus: (r) -> @_compile(
    {tag: 'cat', data: [r, {tag: 'rep', data: r}]})

class FnCompiler extends Compiler
  rule: (r) ->
    # there are so many underscores in this function because coffeescript's
    # scoping rules led to an insidious bug where i was modifying a variable
    # i thought i was shadowing and I WON'T GET FOOLED AGAIN :|
    [_atm, _xpr, _code] = r
    if _code
      _thiscontext = @context
      _transform = (args) ->
        # FIXME: find the number of arguments at compile time & only eval once!
        _argv = ("$#{ai+1}" for ai in [0..args.length]).join(',')
        _evstr = "(function (#{_argv}) #{_code.data});"
        eval(_evstr).apply(_thiscontext, args)
    else
      _transform = (n) -> n

    @rules[_atm.data] = p.transform @_compile(_xpr), _transform

  main: (r) -> @output = toplevelParser @_compile r
  cat: (rs) -> p.cat rs.map(@_compile, this)
  alt: (rs) ->
    if rs.length is 1 then @_compile rs[0] else p.alt rs.map(@_compile, this)
  rep: (r) -> p.many @_compile r
  opt: (r) -> p.opt @_compile r
  term: p.string
  charopt: (rs) -> p.cheat RegExp "^[#{rs}]"

class JSCompiler extends Compiler
  rule: (r) ->
    [_atm, _xpr, _code] = r
    if _code
      tfunc = """
        (function (args) {
          var _evstr, _i, _argv=[];
          for (_i=0;_i<args.length;_i++)
            _argv.push("$"+(_i+1));
          _argv = "(" + _argv.join(',') + ")";
          _evstr = "(function " + _argv + #{JSON.stringify _code.data} + ");";
          return eval(_evstr).apply(__CONTEXT__, args);
        })
      """
    else
      tfunc = "id"
    @rules[_atm.data] = "helpers.transform(#{@_compile _xpr}, #{tfunc})"

  main: (r) ->
    core = require './core.js'
    peg = "{#{
      "#{k}: #{core[k].toString()}" for k of core
    }}"

    helpers = "{transform: function (m, fn) {return peg.alt(m,m,fn);}}"
    @output = """
      (function (__INPUT__) {
        var __CONTEXT__ = {};
        var id = function (n) {return n;};
        var result = function (v,r) {return {val: v, rem: r};};
        var peg = #{peg};
        var helpers = #{helpers};
        return #{@_compile r}(__INPUT__);
      })
    """

  cat: (rs) ->
    _codes = rs.map @_compile, this
    "(#{p.cat.toString()})([#{_codes}])"
  alt: (rs) ->
    _codes = rs.map @_compile, this
    "(#{p.alt.toString()})([#{_codes}])"
  rep: (r) -> "peg.rep(#{@_compile r}, id)"
  opt: (r) -> "peg.opt(#{@_compile r}, id)"
  charopt: (rs) -> "(#{p.cheat.toString()
    })(RegExp(#{JSON.stringify "^[#{rs}]"}))"

  term: (r) -> "(#{p.string.toString()})(#{
    JSON.stringify r},#{JSON.stringify r})"

exports.parse = parse
exports.compilers = {function: FnCompiler, javascript: JSCompiler}
exports.bootstrap = (d) ->
  res = p.transform(parse, (n) -> new FnCompiler().compile n)(d)
  res and res.val

