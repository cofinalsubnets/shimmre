fs = require 'fs'
srcs = {}

exports.src = src = (file) -> srcs[file] ||= fs.readFileSync(file).toString()

exports.srcWithFrontend = srcWithFrontend = (backend) ->
  src('lib/grammar.shimmre') + src(backend)

exports.compile = compile = (data, compiler) ->
  out = compiler data
  if not out or out.rem isnt ''
    throw new SyntaxError "Compile failed due to syntax error:\n  #{
      (if out then out.rem else data)[..60] + ' ...\n  ^'}"
  else out.val[0]

exports.compileFile = (file, compiler) ->
  compile src(file), compiler

exports.compileWithFrontend = (file, compiler) ->
  compile srcWithFrontend(file), compiler

