peg = require './core.js'
char = require './char.js'

id = (n) -> n

exports.oneOf = oneOf = (s) ->
  s.split(//).map((n) -> peg.term n, n).reduce((n, o) -> peg.alt(n, o, id))

exports.many = many = (m) -> peg.rep m, id

exports.many1 = many1 = (m) ->
  peg.cat m, many(m), (a,b) -> [a].concat b

exports.cat = cat = (ms) ->
  ms.reduce(((a,b) -> peg.cat(a, b, (c, d) -> c.concat [d])),
    peg.term('',[]))

exports.alt = alt = (ms) -> ms.reduce((a,b) -> peg.alt(a,b,id))
exports.opt = opt = (m) -> peg.opt m, id

exports.wrap = wrap = (m, w) -> peg.cat(w, peg.cat(m, w, id), (_,n) -> n)

exports.sepBy = sepBy = (m, s) ->
  peg.cat(m, peg.rep(peg.cat(s, m, (_,n)->n), id), (a,b) -> [a].concat b)

exports.string = (s) -> peg.term s, s
exports.stringOf = (s) -> transform many(oneOf(s)), (n) -> n.join ''

exports.transform = transform = (m, fn) -> peg.alt(m, m, fn)

exports.digit = digit = oneOf char.num
exports.space = oneOf char.space
exports.letter = oneOf char.alpha
exports.punctuation = oneOf char.punct
exports.not = peg.notp
exports.and = peg.andp

# just use a regex!
exports.cheat = (re) -> (str) ->
  (res = str.match re) and {val: res[0], rem: str.substr res[0].length}

exports.parseNum = transform(
  cat([opt(oneOf "-"), many1(digit), opt cat [oneOf("."), many1 digit]]),
  (val) -> Number val.map((n) -> n or '').join ''
)

exports.escaped = escaped = (c) -> peg.term "\\#{c}", c

exports.delimited = delimited = (ldelim, rdelim) ->
  innerChar = alt [oneOf(char.all.replace RegExp(rdelim), ''), escaped rdelim]
  transform cat([peg.term(ldelim), many(innerChar), peg.term(rdelim)]), (n) -> n[1]

exports.delimitedString = (l,r) -> transform delimited(l,r), (n) -> n.join('')

