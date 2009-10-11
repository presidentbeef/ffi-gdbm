## ffi-gdbm

An attempt to make gdbm available beyond the C Ruby implementation.

## Installing

You can download and use `gdbm.rb` anyhow you would like.

You can also install it using Ruby Gems:

`jgem install gdbm --source http://gemcutter.org`

## Notes

* Conforms to tests from MRI 1.8.7 and 1.9.1 and follows the C library for MRI if there are contradictions with the documentation
* Should be compatible with gdbm files created with MRI
* Only works with JRuby, as it relies on features from JRuby's FFI which are not available in Ruby FFI 
* Does not work with JRuby 1.3, try using it with JRuby 1.4 or the master from http://github.com/jruby/jruby

## Status

Using JRuby 1.4dev, this lib passes all tests from 1.8.7 and 1.9.1 except those related to [this JRuby bug](http://jira.codehaus.org/browse/JRUBY-4071). It passes all tests with the current 1.5dev.

## Testing

Two sets of tests are included, copied straight from the MRI distribution. However, they do require the use of ObjectSpace, so this is how to run them:

`jruby -X+O -r lib/gdbm test/test_gdbm-1.8.7.rb`

`jruby --1.9 -X+O -r lib/gdbm test/test_gdbm-1.9.1.rb`
