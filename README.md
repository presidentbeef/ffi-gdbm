## ffi-gdbm

An attempt to make [gdbm](http://www.vivtek.com/gdbm/) available beyond the C Ruby implementation.

Faithfully mimics MRI's standard library and is compatible with gdbm files produced by that version.

## Installing

You can download and use `gdbm.rb` anyhow you would like.

You can also install it using Ruby Gems:

`gem install ffi-gdbm`

or, if using JRuby:

`jgem install gdbm`

JRuby does not require further installation, but Rubinius will need the FFI gem:

`gem install ffi`

## Notes

* Conforms to tests from MRI 1.8.7 and 1.9.1 and follows the C library for MRI if there are contradictions with the documentation
* Should be compatible with gdbm files created with MRI's standard library
* Certainly works with JRuby, may work with other alternative Ruby implementations

## Status

Tests passing on 64 bit Linux with

* JRuby 1.7.21 and 9.1.7.0

### Older Tests

Passing all tests with JRuby 1.4, 1.5.3, 1.6 on 32-bit Linux.

Passing all tests with MRI Ruby 1.8.7, 1.9.1, 1.9.2 with Ruby-FFI 0.5.4, 0.6.3, 1.0.7 on 32-bit Linux.

Further testing on other systems is welcome!

## Testing

Two sets of tests are included, copied straight from the MRI distribution. However, they do require the use of ObjectSpace, so this is how to run them with JRuby:

`jruby --1.8 -X+O -r lib/gdbm test/test_gdbm-1.8.7.rb` (Note: these tests only work with JRuby prior to 9.0.0.0)

`jruby -X+O -r ./lib/gdbm test/test_gdbm-1.9.1.rb`

## License

Copyright (c), Justin Collins

This library is released under the same tri-license (GPL/LGPL/CPL) as JRuby.
Please see the COPYING file distributed with JRuby for details.
