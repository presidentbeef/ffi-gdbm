require 'ffi'

module GDBM_FFI
	extend FFI::Library

	class Datum < FFI::Struct
		layout(:dptr, :string, 0, :size, :int, 4)
	end
	
	ffi_lib "gdbm"
	callback :fatal_func, [:string], :void
	attach_function :open, "gdbm_open", [:string, :int, :int, :int, :fatal_func], :pointer
	attach_function :close, "gdbm_close", [:pointer], :void
	attach_function :store, "gdbm_store", [:pointer, :pointer, :pointer, :int], :int
	attach_function :fetch, "gdbm_fetch", [:pointer, :pointer], :pointer
	attach_function :exists, "gdbm_exists", [:pointer, :pointer], :int
	attach_function "gdbm_firstkey", [:pointer], :pointer
	attach_function "gdbm_nextkey", [:pointer, :pointer], :pointer
	attach_function :reorganize, "gdbm_reorganize", [:pointer], :int
	attach_function :sync, "gdbm_sync", [:pointer], :void
	attach_function :error_string, "gdbm_strerror", [:int], :string
	attach_function :setopt, "gdbm_setopt", [:pointer, :int, :pointer, :int], :int

	READER = 0
	WRITER = 1
	WRCREAT = 2
	NEWDB = 3
	FAST = 0x10
	SYNC = 0x20
	NOLOCK = 0x40
	#attach_variable :VERSION, :gdbm_version, :string  #why doesn't this work??
	VERSION = ""
	attach_variable :ERR_NO, :gdbm_errno, :int
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

	def initialize filename, mode = 0666, flags = nil

		mode = -1 if mode.nil?
		flags = 0 if flags.nil?

		fatal = Proc.new  { |msg| raise RuntimeError, msg }

		if flags & RUBY_GDBM_RW_BIT != 0 #Check if flags are appropriate
			flags &= ~RUBY_GDBM_RW_BIT #Remove check to make flag match GDBM constants

			@file = GDBM_FFI.open filename, BLOCKSIZE, flags, mode, fatal
		else
			@file = GDBM_FFI.open filename, BLOCKSIZE, WRCREAT | flags, mode, fatal
			
			@file = GDBM_FFI.open filename, BLOCKSIZE, WRITER | flags, mode, fatal if @file.nil?

			@file = GDBM_FFI.open filename, BLOCKSIZE, READER | flags, mode, fatal if @file.nil?
		end

		if @file.nil?
			#if gdbm_errno == GDBM_FILE_OPEN_ERROR || gdbm_errno == GDBM_CANT_BE_READER || gdbm_errno == GDBM_CANT_BE_WRITER
				#Need to know what the Ruby verion of this would be
				#rb_sys_fail(RSTRING_PTR(file));
			#else
				raise GDBMError, GDBM_FFI.error_string(GDBM_FFI::gdbm_errno);
			#end
		end
	end

	def self.open filename, mode = 0666, flags = nil
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

	def [] key

	end

	def []= key, value

	end

	alias :store :[]=

		def cachesize= size

		end

	def clear
		key = GDBM_FFI


	end

	def close
		GDBM_FFI.close @file
		@file = nil
	end

	def closed?
		@file.nil?
	end

	def delete key

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

	def fastmode= boolean

	end

	def fetch key, default = nil

	end

	def has_key? key

	end

	alias :key :has_key?

	def has_value? value

	end

	alias :value? :has_value?

	def index value

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

	def replace other

	end

	def select

	end

	def shift

	end

	def sync

	end

	def sycnmode= boolean

	end

	def to_a

	end

	def to_hash

	end

	def update other

	end

	def values

	end

	def values_at *keys
		results = []

		keys.each do |k|
			results << fetch(k)
		end
	end
end

if $0 == __FILE__
	g = GDBM.new "hello"
	g.close
end
