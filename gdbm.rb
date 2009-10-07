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

		def size
			#When FFI stores the string, it appends a NULL, thus the stored size
			#is one character longer than the string.
			self[:dsize] - 1
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
	attach_function :error_string, :gdbm_strerror, [ :int ], :string

	READER = 0
	WRITER = 1
	WRCREAT = 2
	NEWDB = 3
	FAST = 0x10
	SYNC = 0x20
	NOLOCK = 0x40
	REPLACE = 1
	FATAL = Proc.new  { |msg| raise RuntimeError, msg }

	attach_variable :error_number, :gdbm_errno, :int
	attach_variable :VERSION, :gdbm_version, :string

	def self.store(file, key, value)
		key_datum = Datum.new key
		val_datum = Datum.new value

		result = gdbm_store file, key_datum, val_datum, GDBM_FFI::REPLACE
		raise GDBMError, last_error if result != 0
	end

	def self.fetch(file, key)
		key_datum = Datum.new key
		
		val_datum = gdbm_fetch file, key_datum

		if val_datum[:dptr].null?
			nil
		else
			val_datum[:dptr].read_string(val_datum.size)
		end
	end

	def self.first_key(file)
		key_datum = GDBM_FFI.gdbm_firstkey file
		if key_datum[:dptr].null?
			nil
		else
			key_datum[:dptr].read_string(key_datum.size)
		end
	end

	def self.delete(file, key)
		return nil if not self.exists? file, key
		key_datum = Datum.new key
		result = gdbm_delete file, key_datum
		raise GDBMError, last_error if result != 0
	end

	def self.exists?(file, key)
		key_datum = Datum.new key

		gdbm_exists(file, key_datum) != 0
	end

	def self.each_pair(file)
		current = self.gdbm_firstkey file
		until current[:dptr].null?
			value = gdbm_fetch file, current
			yield current[:dptr].read_string(current.size), value[:dptr].read_string(value.size)
			current = self.gdbm_nextkey file, current
		end
	end

	def self.each_key(file)
		current = self.gdbm_firstkey file
		until current[:dptr].null?
			yield current[:dptr].read_string(current.size)
			current = self.gdbm_nextkey file, current
		end
	end

	def self.each_value(file)
		current = self.gdbm_firstkey file
		until current[:dptr].null?
			value = gdbm_fetch file, current
			yield value[:dptr].read_string(value.size)
			current = self.gdbm_nextkey file, current
		end
	end

	def self.clear(file)
		until (key = self.gdbm_firstkey(file))[:dptr].null?
			until key[:dptr].null?
				next_key = self.gdbm_nextkey(file, key)
				result = self.gdbm_delete file, key
				raise GDBMError, last_error if result != 0
				key = next_key
			end
		end
	end

	def self.last_error
		error_string(error_number)
	end

	def self.set_fast_mode(file, boolean)
		if boolean
			opt = MemoryPointer.new 1
		else
			opt = MemoryPointer.new 0
		end

		self.set_opt file, FAST, opt, opt.size
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
	VERSION = GDBM_FFI.VERSION 

	def initialize(filename, mode = 0666, flags = nil)

		mode = -1 if mode.nil?
		flags = 0 if flags.nil?
		@file = nil

		if flags & RUBY_GDBM_RW_BIT != 0 #Check if flags are appropriate
			flags &= ~RUBY_GDBM_RW_BIT #Remove check to make flag match GDBM constants

			@file = GDBM_FFI.open filename, BLOCKSIZE, flags, mode, GDBM_FFI::FATAL
		else
			if mode > 0
				@file = GDBM_FFI.open filename, BLOCKSIZE, WRCREAT | flags, mode, GDBM_FFI::FATAL
			end

			@file = GDBM_FFI.open filename, BLOCKSIZE, WRITER | flags, 0, GDBM_FFI::FATAL if @file.nil? or @file.null?
			@file = GDBM_FFI.open filename, BLOCKSIZE, READER | flags, 0, GDBM_FFI::FATAL if @file.nil? or @file.null?
		end

		if @file.nil? or @file.null?
			return if mode == -1 #C code returns Qnil, but we can't
			#if gdbm_errno == GDBM_FILE_OPEN_ERROR || gdbm_errno == GDBM_CANT_BE_READER || gdbm_errno == GDBM_CANT_BE_WRITER
			#Need to convert to ERRNO::...?
			#rb_sys_fail(RSTRING_PTR(file));
			#else
			raise GDBMError, GDBM_FFI.last_error;
			#end
		end
	end

	def self.open(filename, mode = 0666, flags = nil)
		obj = self.new filename, mode, flags

		if block_given?
			begin
				result = yield obj
			ensure
				obj.close unless obj.closed?
			end
			result
		elsif obj.nil?
			nil
		else
			obj
		end
	end

	def [](key)
		GDBM_FFI.fetch file, key
	end

	def []=(key, value)
		modifiable?
		GDBM_FFI.store file, key, value
	end

	alias :store :[]=

	def cachesize=(size)

	end

	def clear
		modifiable?
		GDBM_FFI.clear file
		self
	end

	def close
		if closed?
			raise RuntimeError, "closed GDBM file"
		else
			GDBM_FFI.close @file
			@file = nil unless frozen?
		end
	end

	def closed?
		@file.nil? or @file.null?
	end

	def delete(key)
		modifiable?
		value = self[key]
		#This is bizarre and not mentioned in the docs,
		#but this is what the tests expect and what the MRI
		#version does.
		if value.nil? and block_given?
			value = yield key
		end
		GDBM_FFI.delete file, key
		value
	end

	def delete_if
		modifiable?
		rejects = []
		begin
			GDBM_FFI.each_pair(file) do |k,v|
				if yield k, v
					rejects << k
				end
			end
		#unsure about this, but it handles breaking during
		#the iteration
		ensure
			rejects.each do |k|
				GDBM_FFI.delete file, k
			end
		end

		self
	end

	alias :reject! :delete_if

	def each_key(&block)
		GDBM_FFI.each_key file, &block
		self
	end

	def each_pair(&block)
		GDBM_FFI.each_pair file, &block
		self
	end

	alias :each :each_pair

	def each_value(&block)
		GDBM_FFI.each_value file, &block
		self
	end

	def empty?
		key = GDBM_FFI.first_key file
		key.nil?
	end

	def fastmode=(boolean)
		GDBM_FFI.set_fast_mode file, boolean
	end

	def fetch(key, default = nil)
		result = GDBM_FFI.fetch file, key
		if result.nil?
			if default
				default
			elsif block_given?
				yield key
			else
				raise IndexError, "key not found"
			end
		else
			result
		end
	end

	def has_key?(key)
		GDBM_FFI.exists? file, key
	end

	alias :key? :has_key?
	alias :member? :has_key?
	alias :include? :has_key?

	def has_value?(value)
		GDBM_FFI.each_value(file) do |v|
			if v == value
				return true
			end
		end
		false
	end

	alias :value? :has_value?

	def index(value)
		GDBM_FFI.each_pair(file) do |k,v|
			if value == v
				return k
			end
		end
		nil
	end

	def invert
		result = {}

		GDBM_FFI.each_pair(file) do |k,v|
			result[v] = k
		end

		result
	end

	def keys
		keys = []

		GDBM_FFI.each_key(file) do |k|
			keys << k
		end

		keys
	end

	def length
		len = 0

		GDBM_FFI.each_key(file) do |k|
			len = len + 1
		end

		len
	end

	alias :size :length

	def nil?
		@file.nil? or @file.null?
	end

	def reject
		result = {}

		GDBM_FFI.each_pair(file) do |k,v|
			if not yield k, v
				result[k] = v
			end
		end

		result
	end

	def reorganize
		modifiable?
		GDBM_FFI.reorganize file
		self
	end

	def replace(other)
		self.clear
		self.update other
		self
	end

	def select *args
		result = []
		#This method behaves completely contrary to what the docs state:
		#http://ruby-doc.org/stdlib/libdoc/gdbm/rdoc/classes/GDBM.html#M000318
		#Instead, it yields a pair and returns [[k1, v1], [k2, v2], ...]
		#But this is how it is in 1.8.7 and 1.9.1, so...

		if block_given?
			if args.length > 0
				raise ArgumentError, "wrong number of arguments(#{args.length} for 0)"
			end

			GDBM_FFI.each_pair(file) do |k, v|
				if yield k, v
					result << [k, v]
				end
			end
		#This is for 1.8.7 compatibility
		elsif RUBY_VERSION <= "1.8.7"
			warn "GDBM#select(index..) is deprecated; use GDBM#values_at"

			result = values_at *args
		else
			result = []
		end

		result
	end

	def shift
		modifiable?
		key = GDBM_FFI.first_key file
		if key
			value = GDBM_FFI.fetch file, key
			GDBM_FFI.delete file, key
			[key, value]
		else
			nil
		end
	end

	def sync
		modifiable?
		GDBM_FFI.sync file
		self
	end

	def syncmode=(boolean)
		GDBM_FFI.set_fast_mode file, !boolean
	end

	def to_a
		result = []
		GDBM_FFI.each_pair(file) do |k,v|
			result << [k, v]
		end
		result
	end

	def to_hash
		result = {}
		GDBM_FFI.each_pair(file) do |k,v|
			result[k] = v
		end
		result
	end

	def update(other)
		other.each_pair do |k,v|
			GDBM_FFI.store file, k, v
		end
		self
	end

	def values
		values = []

		GDBM_FFI.each_value(file) do |v|
			values << v
		end

		values
	end

	def values_at(*keys)
		results = []

		keys.each do |k|
			results << self[k]
		end

		results
	end

	private

	def modifiable?
		#raise SecurityError, "Insecure operation at level #$SAFE" if $SAFE >= 4 #Not currently supported in JRuby
		if self.frozen?
			if RUBY_VERSION > "1.8.7"
				raise RuntimeError, "Can't modify frozen #{self}"
			else
				raise TypeError, "Can't modify frozen #{self}"
			end
		end
	end

	def file
		unless @file.nil? or @file.null?
			@file
		else
			raise(RuntimeError, "closed GDBM file")
		end
	end
end

if $0 == __FILE__
	File.delete "hello" if File.exists? "hello"
	p GDBM::VERSION
	GDBM.open "hello", 0400 do |g|
		g["hell\000"] = "wor\000ld"
		g["goodbye"] = "cruel world"
		n = 0
		g.delete_if do |k,v|
			break if n == 1
			n = 1
		end	
		p g.length
	end
	g = GDBM.open "hello"
	g.close
	puts "closed"
	File.delete "hello" if File.exists? "hello"
end
