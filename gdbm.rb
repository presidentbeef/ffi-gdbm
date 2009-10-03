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
	#attach_variable :VERSION, :gdbm_version, :string  #why doesn't this work??
	VERSION = ""
	FATAL = Proc.new  { |msg| raise RuntimeError, msg }

	attach_variable :error_number, :gdbm_errno, :int

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
			value = gdbm_fetch file, current
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
			if mode > 0
				@file = GDBM_FFI.open filename, BLOCKSIZE, WRCREAT | flags, mode, GDBM_FFI::FATAL
			end

			@file = GDBM_FFI.open filename, BLOCKSIZE, WRITER | flags, 0, GDBM_FFI::FATAL if @file.nil? or @file.null?

			@file = GDBM_FFI.open filename, BLOCKSIZE, READER | flags, 0, GDBM_FFI::FATAL if @file.nil? or @file.null?
		end

		if @file.nil? or @file.null?
			return nil if mode == -1
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
				obj.close unless obj.closed?
			end
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
		GDBM_FFI.close @file if @file
		@file = nil
	end

	def closed?
		@file.nil? or @file.null?
	end

	def delete(key)
		modifiable?
		value = self.fetch key
		GDBM_FFI.delete file, key
		value
	end

	def delete_if
		modifiable?
		rejects = []
		GDBM_FFI.each_pair(file) do |k,v|
			if yield k, v
				rejects << k
			end
		end

		rejects.each do |k|
			GDBM_FFI.delete file, k
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

	end

	def fetch(key, default = nil)
		result = GDBM_FFI.fetch file, key
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

		GDBM_FFI.each_value(file) do |k|
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

	def select
		result = []
		GDBM_FFI.each_value(file) do |v|
			if yield v
				result << v
			end
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

	def sycnmode=(boolean)

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
			results << fetch(k)
		end

		results
	end

	private

	def modifiable?
		#raise SecurityError, "Insecure operation at level #$SAFE" if $SAFE >= 4 #Not currently supported in JRuby
		raise RuntimeError, "Can't modify frozen #{self}" if self.frozen?
	end

	def file
		if @file.nil? and not @file.null?
			@file
		else
			raise(RuntimeError, "closed GDBM file")
		end
	end
end

if $0 == __FILE__
	File.delete "hello" if File.exists? "hello"
	GDBM.open "hello", 0400 do |g|
		g["hell\000"] = "wor\000ld"
		g["goodbye"] = "cruel world"
		g.replace({"goodbye" => "everybody", "hello" => "somebody"})
		p g.to_hash
	end
	g = GDBM.open "hello", nil
	g.close
	puts "closed"
	File.delete "hello" if File.exists? "hello"
end
