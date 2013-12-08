result = (v,r) -> {val: v, rem: r}

exports.term = (t, m) -> (str) ->
  str.substr(0, t.length) is t and result(m, str.substr t.length)

exports.cat = (p1, p2, t) -> (str) ->
  (t1 = p1 str) and (t2 = p2 t1.rem) and result t(t1.val, t2.val), t2.rem

exports.alt = (p1, p2, t) -> (str) ->
  (res = p1(str) or p2 str) and result t(res.val), res.rem

exports.opt = (p, t) -> (str) ->
  (res = p str) and result(t(res.val), res.rem) or result t(), str

exports.rep = (p, t) -> (str) ->
  result t(while res = p str
    str = res.rem
    res.val), str

exports.andp = (p1, p2, t) -> (str) ->
  (r1 = p1 str) and (r2 = p2 str) and result t(r1.val, r2.val), str

exports.notp = (p, m) -> (str) -> not p str and result m(str), str

