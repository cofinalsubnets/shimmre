# shimmre

Shucks Howdy! It's a Mini Metagrammar Reification Engine

## what

a self-hosting PEG-based parser/compiler generator inspired by OMeta in under
300 lines of combined CoffeeScript / its own metagrammar. unstable and for the
moment lacking amenities like compilation to JavaScript & a test suite.

## how

1. run `shimmre.shimmre` through the compiler in `bootstrap.coffee` to obtain a
   bootstrapped shimmre;
2. run `shimmre.shimmre` through the bootstrapped shimmre to obtain a
   metashimmre;
3. repeat as desired.

shimmre is an experimental toy and any aspect of its functioning or API can and
should be expected to break without notice, at least until i write some
automated tests.

