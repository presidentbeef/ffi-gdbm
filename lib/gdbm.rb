=begin
JRuby access to gdbm via FFI. Faithfully mimics MRI's standard library and is 
compatible with gdbm files produced by that version.

Author: Justin Collins
Based on the C version by: yugui
Website: http://github.com/presidentbeef/ffi-gdbm
Documentation: http://ruby-doc.org/stdlib/libdoc/gdbm/rdoc/classes/GDBM.html
JRuby: http://www.jruby.org/
gdbm: http://directory.fsf.org/project/gdbm/

Copyright (c) 2009, Justin Collins

This library is released under the same tri-license (GPL/LGPL/CPL) as JRuby.
Please see the COPYING file distributed with JRuby for details.
=end

unless defined? FFI
  require 'ffi'
end

module GDBM_FFI
  extend FFI::Library
  ffi_lib "gdbm"

  #Note that MRI does not store the null byte, so neither does this version,
  #even though FFI automatically appends one to the String.
  class Datum < FFI::Struct
    layout :dptr, :pointer, :dsize, :int

    #Expects either a MemoryPointer or a String as an argument.
    #If it is given a String, it will initialize the fields, including
    #setting dsize.
    def initialize(*args)
      if args.length == 1 and args[0].is_a? String
        super()
        self.dptr = args[0]
        self[:dsize] = args[0].length
      else
        super
      end
    end

    def value
      if self[:dptr].nil? or self[:dptr].null?
        nil
      else
        self[:dptr].read_string(self.size)
      end
    end

    #_Do not use_. Creates a new MemoryPointer from the String.
    def dptr=(str)
      @dptr = FFI::MemoryPointer.from_string(str)
      self[:dptr] = @dptr
    end

    #Returns the size of the stored String.
    def size
      self[:dsize]
    end
  end

  callback :fatal_func, [:string], :void

  #Attach gdbm functions
  attach_function :gdbm_open, [ :string, :int, :int, :int, :fatal_func ], :pointer
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
  CACHE_SIZE = 1
  FAST_MODE = 2
  SYNC_MODE = 3
  CANT_BE_READER = 9
  CANT_BE_WRITER = 10
  FILE_OPEN_ERROR = 3

  FATAL = Proc.new  { |msg| raise RuntimeError, msg }

  attach_variable :error_number, :gdbm_errno, :int
  attach_variable :VERSION, :gdbm_version, :string

  #Store the given Strings in _file_. _file_ is always GDBM_FILE pointer in these functions.
  def self.store(file, key, value)
    key_datum = Datum.new key
    val_datum = Datum.new value

    result = gdbm_store file, key_datum, val_datum, GDBM_FFI::REPLACE
    raise GDBMError, last_error if result != 0
  end

  #Fetch a String from the _file_ matching the given _key_. Returns _nil_ if
  #there is no such key.
  def self.fetch(file, key)
    key_datum = Datum.new key
    
    val_datum = gdbm_fetch file, key_datum

    val_datum.value
  end

  #Returns the first key in the _file_.
  def self.first_key(file)
    key_datum = GDBM_FFI.gdbm_firstkey file
    key_datum.value
  end

  #Deletes the _key_ from the _file_.
  def self.delete(file, key)
    return nil if not self.exists? file, key
    key_datum = Datum.new key
    result = gdbm_delete file, key_datum
    raise GDBMError, last_error if result != 0
  end

  #Checks if the _file_ contains the given _key_.
  def self.exists?(file, key)
    key_datum = Datum.new key

    gdbm_exists(file, key_datum) != 0
  end

  #Iterates over each _key_, _value_ pair in the _file_.
  def self.each_pair(file)
    current = self.gdbm_firstkey file
    until current.value.nil?
      value = gdbm_fetch file, current
      yield current.value, value.value
      current = self.gdbm_nextkey file, current
    end
  end

  #Iterates over each key in the _file_.
  def self.each_key(file)
    current = self.gdbm_firstkey file
    until current.value.nil?
      yield current.value
      current = self.gdbm_nextkey file, current
    end
  end

  #Iterates over each value in the _file_.
  def self.each_value(file)
    current = self.gdbm_firstkey file
    until current.value.nil?
      value = gdbm_fetch file, current
      yield value.value
      current = self.gdbm_nextkey file, current
    end
  end

  #Deletes all keys and values from the _file_.
  def self.clear(file)
    until (key = self.gdbm_firstkey(file)).value.nil?
      until key.value.nil?
        next_key = self.gdbm_nextkey(file, key)
        result = self.gdbm_delete file, key
        raise GDBMError, last_error if result != 0
        key = next_key
      end
    end
  end

  #Returns the last error encountered from the gdbm library as a String.
  def self.last_error
    error_string(error_number)
  end

  #Opens a gdbm file. Returns the GDBM_FILE pointer, which should be treated
  #as an opaque value, to be passed in to GDBM_FFI methods.
  def self.open(filename, blocksize, flags, mode)
    self.gdbm_open filename, blocksize, flags, mode, FATAL
  end

  #Sets the cache size.
  def self.set_cache_size(file, size)
    opt = FFI::MemoryPointer.new size
    self.set_opt file, CACHE_SIZE, opt, opt.size
  end

  #Sets the sync mode.
  def self.set_sync_mode(file, boolean)
    if boolean
      opt = FFI::MemoryPointer.new 1
    else
      opt = FFI::MemoryPointer.new 0
    end

    self.set_opt file, SYNC_MODE, opt, opt.size
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

      @file = GDBM_FFI.open filename, BLOCKSIZE, flags, mode
    else
      if mode >= 0
        @file = GDBM_FFI.open filename, BLOCKSIZE, WRCREAT | flags, mode
      end

      @file = GDBM_FFI.open filename, BLOCKSIZE, WRITER | flags, 0 if @file.nil? or @file.null?
      @file = GDBM_FFI.open filename, BLOCKSIZE, READER | flags, 0 if @file.nil? or @file.null?
    end

    if @file.nil? or @file.null?
      return if mode == -1 #C code returns Qnil, but we can't
      if GDBM_FFI.error_number == GDBM_FFI::FILE_OPEN_ERROR || 
        GDBM_FFI.error_number == GDBM_FFI::CANT_BE_READER || 
        GDBM_FFI.error_number == GDBM_FFI::CANT_BE_WRITER

        raise SystemCallError.new(GDBM_FFI.last_error, FFI.errno)
      else
        raise GDBMError, GDBM_FFI.last_error;
      end
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
    GDBM_FFI.set_cache_size file, size
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
    GDBM_FFI.set_sync_mode file, !boolean
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
    if RUBY_VERSION >= "1.9"
      warn "GDBM#index is deprecated; use GDBM#key"
    end

    self.key(value)
  end

  def invert
    result = {}

    GDBM_FFI.each_pair(file) do |k,v|
      result[v] = k
    end

    result
  end

  def key(value)
    GDBM_FFI.each_pair(file) do |k,v|
      if v == value
        return k
      end
    end
    nil
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

  def select(*args)
    result = []
    #This method behaves completely contrary to what the docs state:
    #http://ruby-doc.org/stdlib/libdoc/gdbm/rdoc/classes/GDBM.html#M000318
    #Instead, it yields a pair and returns [[k1, v1], [k2, v2], ...]
    #But this is how it is in 1.8.7 and 1.9.1, so...
    #
    #Update: Docs have been patched: http://redmine.ruby-lang.org/repositories/revision/1?rev=25300

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

      result = values_at(*args)
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
    GDBM_FFI.set_sync_mode file, boolean
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

  #Raises a RuntimeError if the file is closed.
  def file
    unless @file.nil? or @file.null?
      @file
    else
      raise(RuntimeError, "closed GDBM file")
    end
  end
end

