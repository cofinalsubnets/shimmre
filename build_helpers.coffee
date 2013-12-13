fs = require 'fs'
boot = require './lib/shimmre'
srcs = {}

exports.src = src = (file) -> srcs[file] ||= fs.readFileSync file

exports.srcWithFrontend = srcWithFrontend = (backend) ->
  src('lib/grammar.shimmre') + src(backend)

exports.compile = compile = (data) ->
  jsc = compiler()
  out = jsc(data)
  if not out or out.rem isnt ''
    throw new SyntaxError "Compile failed due to syntax error:\n  #{
      (if out then out.rem else data)[..60] + ' ...\n  ^'}"
  else out.val[0]

exports.compileFile = (file) ->
  compile src(file)

exports.compileWithFrontend = (file) ->
  compile srcWithFrontend(file)

jsCompiler = null
exports.compiler = compiler = ->
  jsCompiler ||= boot.compile(srcWithFrontend 'lib/jsc.shimmjs').val[0]

