# shimmre

Shucks Howdy! It's a Mini Metagrammar Reification Engine

## what

a self-hosting PEG-based parser/compiler generator inspired by OMeta. it lives
in ~300 lines of combined CoffeeScript / JavaScript / its own metalanguage and
should be extensible to new languages with minimal effort. currently lacking
amenities such as a test suite or a stable api.

## how

1. run `shimmre.shimmre` through the compiler in `bootstrap.coffee` to obtain a
   bootstrapped shimmre;
2. run `shimmre.shimmre` through a shimmre to obtain a metashimmre;
3. run `shimmre.jsc` through a shimmre to obtain a shimmre-to-JavaScript
   compiler;
4. repeat / combine steps as desired.

shimmre is an experimental toy and any aspect of its functioning or API can and
should be expected to break without notice.

