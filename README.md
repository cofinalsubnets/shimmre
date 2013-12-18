# shimmre

_Shucks Howdy! It's a Mini Metagrammar Reification Engine_

Shimmre is a self-hosting\* parser specification language written CoffeeScript.
It is based on parsing expression grammars (PEGs) and inspired by OMeta and my
experiences using parser combinator libraries like Haskell's Parsec. The
baseline implementation lives in a single literate CoffeeScript file containing
under 300 lines of actual code. A mostly feature-complete self-implementation
with JavaScript as the host language also exists and is significantly shorter.
It shares its front-end with an experimental shimmre-to-Ruby compiler.

Shimmre is designed to be simple to implement in new host languages, and shimmre
code is meant to be as portable as possible across implementations.

For more information, start reading `lib/shimmre.litcoffee`.

\* Since shimmre embeds a "host" language, this wants some qualification.
Self-hosting here means that there exists a shimmre/x
(shimmre-with-host-language-x) program that implements shimmre/x. In particular,
a shimmre/js program is provided that implements shimmre/js.

