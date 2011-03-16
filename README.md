## ffi-gdbm

An attempt to make [gdbm](http://www.vivtek.com/gdbm/) available beyond the C Ruby implementation.

Faithfully mimics MRI's standard library and is compatible with gdbm files produced by that version.

## Installing

You can download and use `gdbm.rb` anyhow you would like.

You can also install it using Ruby Gems:

`gem install gdbm`

or, if using JRuby:

`jgem install gdbm`

## Notes

* Conforms to tests from MRI 1.8.7 and 1.9.1 and follows the C library for MRI if there are contradictions with the documentation
* Should be compatible with gdbm files created with MRI's standard library
* Certainly works with JRuby, may work with other alternative Ruby implementations

## Status

Passing all tests with JRuby 1.4, 1.5.3, 1.6 on 32-bit Linux. There may (or may not) be issues using 64-bit.

Passing all tests with MRI Ruby 1.8.7, 1.9.1, 1.9.2 with Ruby-FFI 0.5.4, 0.6.3, 1.0.7 on 32-bit Linux.

Does not currently work with Rubinius' FFI, which seems to be wildly different from the FFI gem. Please let me know if this changes.

Something weird happens with temp files (used in tests) with JRuby on Ubuntu. For some reason, it gets permission denied when trying to delete them. Any thoughts on that would be helpful.

Further testing on other systems is welcome!

## Testing

Two sets of tests are included, copied straight from the MRI distribution. However, they do require the use of ObjectSpace, so this is how to run them with JRuby:

`jruby -X+O -r lib/gdbm test/test_gdbm-1.8.7.rb`

`jruby --1.9 -X+O -r lib/gdbm test/test_gdbm-1.9.1.rb`

## License

Copyright (c) 2009, Justin Collins

This library is released under the same tri-license (GPL/LGPL/CPL) as JRuby.
Please see the COPYING file distributed with JRuby for details.
