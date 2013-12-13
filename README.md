# shimmre

_Shucks Howdy! It's a Mini Metagrammar Reification Engine_

Shimmre is a PEG-based parser/compiler generator inspired by OMeta. It lives in
~300 lines of combined CoffeeScript / JavaScript / itself and is designed to be
self-hosting and portable to new languages with minimal effort.

Currently a self-hosted implementation exists only for shimmre/js (shimmre with
JavaScript as the host language), but there is a (probably flaky) Ruby compiler
for shimmre/rb (written in shimmre/js) that can at least handle a simple RPN
calculator.

