" Vim syntax file
" Language:   shimmre/js

if exists('b:current_syntax') && b:current_syntax == 'shimmre'
  finish
endif

syn include @shimJS syntax/javascript.vim

syn match shimOp /\%(|\|+\|-\|!\|&\|*\|?\|@\)/ display
hi def link shimOp Operator

syn match shimRuleDef /\%(<-\|->\)/ display
hi def link shimRuleDef Keyword

syn match shimComment /;.*/
hi def link shimComment Comment

syn region shimBracket start=/\[/ skip=/\\\\\|\\\]/ end=/\]/
hi def link shimBracket Character

syn match shimTerm /"\%(\\"\|[^"]\)*"/
syn match shimTerm /'\%(\\'\|[^']\)*'/
hi def link shimTerm String

syn match shimParen /\%((\|)\)/
hi def link shimParen Delimiter

syn match shimMain /\<main\>/
hi def link shimMain Keyword

syn match shimRuleName /\h\%(\w\|['-]\)*\%(\%(\s\|;.*$\)*\%(->\|<-\)\)\@=/ display
hi def link shimRuleName Identifier

syn region shimCodeBlock start=/\%(->\n\?\)\@<=\%(.\|\_$\)/ end=/\_^\S\@=/ contains=@shimJS

if !exists('b:current_syntax')
  let b:current_syntax = 'shimmre'
endif
