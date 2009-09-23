require 'ffi'

class GDBM
	extend FFI::Library
	include Enumerable

	set_ffi_lib "gdbm"

 	RUBY_GDBM_RW_BIT = 0x20000000

	READER = nil
	WRITER = nil
	WRCREAT = nil
	NEWDB = nil
	FAST = nil
	VERSION = nil

	def initialize filename, mode = 0666, flags = nil

	end

	def self.open filename, mode = 0666, flags = nil
		if block_given?
			begin

			ensure

			end
		else
			self.new filename, mode, flags
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

	end

	def close

	end

	def closed?

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
			fetch k
		end
	end

	private

	def gdbm_fatal msg
		raise RuntimeError, msg
	end

	def closed_dbm
		raise RuntimeError, "Closed GDBM file"
	end
end
