require 'ffi'

module GDBM_FFI
	extend FFI::Library
	ffi_lib "gdbm"

	class Datum < FFI::Struct
		layout :dptr, :pointer,	:dsize, :int

		def initialize(*args)
			if args.length == 0 or (args.length == 1 and args[0].is_a? FFI::MemoryPointer)
				super
			elsif args.length == 1 and args[0].is_a? String
				super()
				self.dptr = args[0]
				self[:dsize] = args[0].length + 1
			end
		end

		def dptr=(str)
			@dptr = FFI::MemoryPointer.from_string(str)
			self[:dptr] = @dptr
		end

		def dptr
			@dptr.get_string(0)
		end
	end

	callback :fatal_func, [:string], :void

      	attach_function :open, :gdbm_open, [ :string, :int, :int, :int, :fatal_func ], :pointer
	attach_function :close, :gdbm_close, [ :pointer ], :void
	attach_function :gdbm_store, [ :pointer, Datum.by_value, Datum.by_value, :int ], :int
	attach_function :gdbm_fetch, [ :pointer, Datum.by_value ], Datum.by_value
	attach_function :gdbm_delete, [ :pointer, Datum.by_value ], :int
	attach_function :gdbm_firstkey, [ :pointer ], Datum.by_value
	attach_function :gdbm_nextkey, [ :pointer, Datum.by_value ], Datum.by_value
	attach_function :reorganize, :gdbm_reorganize, [ :pointer ], :int
	attach_function :sync, :gdbm_sync, [ :pointer ], :void
	attach_function :gdbm_exists, [ :pointer, Datum.by_value ], :int
	attach_function :set_opt, :gdbm_setopt, [ :pointer, :int, :pointer, :int ], :int
	attach_function :gdbm_strerror, [ :int ], :string

	READER = 0
	WRITER = 1
	WRCREAT = 2
	NEWDB = 3
	FAST = 0x10
	SYNC = 0x20
	NOLOCK = 0x40
	REPLACE = 1
	#attach_variable :VERSION, :gdbm_version, :string  #why doesn't this work??
	VERSION = ""
	FATAL = Proc.new  { |msg| raise RuntimeError, msg }

	attach_variable :ERR_NO, :gdbm_errno, :int

	def self.store(file, key, value)
		key_datum = Datum.new key
		val_datum = Datum.new value

		gdbm_store file, key_datum, val_datum, GDBM_FFI::REPLACE
	end

	def self.fetch(file, key)
		key_datum = Datum.new key
		
		val_datum = gdbm_fetch file, key_datum

		if val_datum[:dptr].null?
			nil
		else
			val_datum[:dptr]
		end
	end

	def self.exists?(file, key)
		key_datum = Datum.new key

		gdbm_exists(file, key_datum) != 0
	end

	def self.first_key(file)

	end

	def self.next_key(file, current_key)

	end
end

class GDBMError < StandardError; end
class GDBMFatalError < Exception; end

class GDBM
	include Enumerable

	#This constant is to check if a flag is READER, WRITER, WRCREAT, or NEWDB
	RUBY_GDBM_RW_BIT = 0x20000000 

	BLOCKSIZE = 2048
	READER = GDBM_FFI::READER | RUBY_GDBM_RW_BIT 
	WRITER = GDBM_FFI::WRITER | RUBY_GDBM_RW_BIT
	WRCREAT = GDBM_FFI::WRCREAT | RUBY_GDBM_RW_BIT
	NEWDB = GDBM_FFI::NEWDB | RUBY_GDBM_RW_BIT
	FAST = GDBM_FFI::FAST
	SYNC = GDBM_FFI::SYNC
	NOLOCK = GDBM_FFI::NOLOCK
	VERSION = GDBM_FFI::VERSION 

	def initialize(filename, mode = 0666, flags = nil)

		mode = -1 if mode.nil?
		flags = 0 if flags.nil?


		if flags & RUBY_GDBM_RW_BIT != 0 #Check if flags are appropriate
			flags &= ~RUBY_GDBM_RW_BIT #Remove check to make flag match GDBM constants

			@file = GDBM_FFI.open filename, BLOCKSIZE, flags, mode, GDBM_FFI::FATAL
		else
			@file = GDBM_FFI.open filename, BLOCKSIZE, WRCREAT | flags, mode, GDBM_FFI::FATAL

			@file = GDBM_FFI.open filename, BLOCKSIZE, WRITER | flags, mode, GDBM_FFI::FATAL if @file.nil?

			@file = GDBM_FFI.open filename, BLOCKSIZE, READER | flags, mode, GDBM_FFI::FATAL if @file.nil?
		end

		if @file.nil?
			#if gdbm_errno == GDBM_FILE_OPEN_ERROR || gdbm_errno == GDBM_CANT_BE_READER || gdbm_errno == GDBM_CANT_BE_WRITER
			#Need to know what the Ruby version of this would be
			#rb_sys_fail(RSTRING_PTR(file));
			#else
			raise GDBMError, GDBM_FFI.error_string(GDBM_FFI::gdbm_errno);
			#end
		end
	end

	def self.open(filename, mode = 0666, flags = nil)
		obj = self.new filename, mode, flags

		if block_given?
			begin
				yield obj
			ensure
				obj.close
			end
		else
			obj
		end
	end

	def [](key)
		GDBM_FFI.fetch @file, key
	end

	def []=(key, value)
		GDBM_FFI.store @file, key, value
	end

	alias :store :[]=

	def cachesize=(size)

	end

	def clear

	end

	def close
		GDBM_FFI.close @file if @file
		@file = nil
	end

	def closed?
		@file.nil?
	end

	def delete(key)

	end

	def delete_if

		self
	end

	alias :reject! :delete_if

	def each_key

		self
	end

	def each_pair

		self
	end

	def each_value

		self
	end

	def empty?

	end

	def fastmode=(boolean)

	end

	def fetch(key, default = nil)
		result = GDBM_FFI.fetch @file, key
		if result.nil?
			if default
				default
			elsif block_given?
				yield key
			end
		else
			result
		end
	end

	def has_key?(key)
		GDBM_FFI.exists? @file, key
	end

	alias :key? :has_key?

	def has_value?(value)

	end

	alias :value? :has_value?

	def index(value)

	end

	def invert

	end

	def keys

	end

	def length

	end

	alias :size :length

	def reject

	end

	def reorganize

		self
	end

	def replace(other)

	end

	def select

	end

	def shift

	end

	def sync
		GDBM_FFI.sync @file
	end

	def sycnmode=(boolean)

	end

	def to_a

	end

	def to_hash

	end

	def update(other)

	end

	def values

	end

	def values_at(*keys)
		results = []

		keys.each do |k|
			results << fetch(k)
		end

		results
	end
end

if $0 == __FILE__
	File.delete "hello" if File.exists? "hello"
	g = GDBM.new "hello"
	g["hello"] = "world"
	puts "Error number: #{GDBM_FFI.gdbm_strerror(GDBM_FFI.ERR_NO)}"
	puts "Has key 'hello'? #{g.has_key? "hello"}"
	puts "Value: #{g["hello"].inspect}"
	puts "Has key 'goodbye'? #{g.has_key? "goodbye"}"
	puts "Default value: #{g.fetch("goodbye"){|k| k + "yo" }}"
	puts "Error number: #{GDBM_FFI.gdbm_strerror(GDBM_FFI.ERR_NO)}"
	g.close
	puts "closed"
	puts g.closed?
	File.delete "hello" if File.exists? "hello"
end
