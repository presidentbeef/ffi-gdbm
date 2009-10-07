An attempt to make gdbm available beyond the C Ruby implementation.

### Notes

* Conforms to tests for 1.8.7 and 1.9.1 and follows the C library for MRI if there are contradictions with documentation
* Should be compatible with gdbm files created with MRI
* Does not work with JRuby 1.3, try using it JRuby 1.4 or the master from http://github.com/jruby/jruby
* Only works with JRuby, as it relies on features from JRuby's FFI that are not available in Ruby FFI 

### Testing

Two sets of tests are included, copied straight from the MRI distribution. However, they do require the use of ObjectSpace, so this is how to run them:

`jruby -X+O test/test_gdbm-1.8.7.rb`

`jruby --1.9 -X+O test/test_gdbm-1.9.1.rb`
