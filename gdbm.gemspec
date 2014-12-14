Gem::Specification.new do |s|
	s.name = %q{gdbm}
	s.version = "1.3.0"
	s.authors = ["Justin Collins"]
	s.summary = %q{Provides access to gdbm through Ruby-FFI, particularly for JRuby and other alternative Ruby implementations.}
	s.homepage = %q{http://github.com/presidentbeef/ffi-gdbm}
	s.description = %q{This library provides a gdbm library compatible with the MRI standard library, but using Ruby-FFI rather than a C extension. This allows gdbm to easily be used from alternative Ruby implementations, such as JRuby. It can also be used with MRI, if there is some kind of need for that.}
	s.files = [ "README.md", "lib/gdbm.rb"]
end
