Gem::Specification.new do |s|
	s.name = %q{gdbm}
	s.version = "0.9"
	s.has_rdoc = false
	s.authors = ["Justin Collins"]
	s.summary = %q{Provides JRuby access to gdbm.}
	s.homepage = %q{http://github.com/presidentbeef/ffi-gdbm}
	s.description = %q{This library provides a JRuby gdbm library compatible with the MRI standard library.}
	s.files = [ "README.md", "lib/gdbm.rb", "test/test_gdbm-1.8.7.rb", "test/test_gdbm-1.9.1.rb"]
end
