require "yomikomu/version"

module Yomikomu
  STATISTICS = Hash.new(0)

  def self.prefix
    unless yomu_dir = ENV['YOMIKOMU_STORAGE_DIR']
      yomu_dir = File.expand_path("~/.ruby_binaries")
    end
    Dir.mkdir(yomu_dir) unless File.exist?(yomu_dir)
    "#{yomu_dir}/cb."
  end

  YOMIKOMU_AUTO_COMPILE = ENV['YOMIKOMU_AUTO_COMPILE'] == 'true'
  YOMIKOMU_USE_MMAP = ENV['YOMIKOMU_USE_MMAP']

  def self.status
    STDERR.puts "[YOMIKOMU:INFO] (pid:#{Process.pid}) " +
                ::Yomikomu::STATISTICS.map{|k, v| "#{k}: #{v}"}.join(', ')
  end

  if $VERBOSE || ENV['YOMIKOMU_INFO'] == 'true'
    def self.info
      STDERR.puts "[YOMIKOMU:INFO] (pid:#{Process.pid}) #{yield}"
    end
    at_exit{
      status
    }
  else
    def self.info
    end
  end

  if ENV['YOMIKOMU_DEBUG'] == 'true'
    def self.debug
      STDERR.puts "[YOMIKOMU:DEBUG] (pid:#{Process.pid}) #{yield}"
    end
  else
    def self.debug
    end
  end

  class NullStorage
    def load_iseq fname; end
    def compile_and_store_iseq fname; end
    def remove_compiled_iseq fname; end
  end

  class BasicStorage
    def initialize
      require 'digest/sha1'
    end

    def load_iseq fname
      iseq_key = iseq_key_name(fname)

      if compiled_iseq_exist?(fname, iseq_key) && compiled_iseq_is_younger?(fname, iseq_key)
        ::Yomikomu::STATISTICS[:loaded] += 1
        ::Yomikomu.debug{ "load #{fname} from #{iseq_key}" }
        binary = read_compiled_iseq(fname, iseq_key)
        iseq = RubyVM::InstructionSequence.load_from_binary(binary)
        # p [extra_data(iseq.path), RubyVM::InstructionSequence.load_from_binary_extra_data(binary)]
        # raise unless extra_data(iseq.path) == RubyVM::InstructionSequence.load_from_binary_extra_data(binary)
        iseq
      elsif YOMIKOMU_AUTO_COMPILE
        compile_and_store_iseq(fname, iseq_key)
      else
        ::Yomikomu::STATISTICS[:ignored] += 1
        ::Yomikomu.debug{ "ignored #{fname}" }
        nil
      end
    end

    def extra_data fname
      "SHA-1:#{::Digest::SHA1.file(fname).digest}"
    end

    def compile_and_store_iseq fname, iseq_key = iseq_key_name(fname = File.expand_path(fname))
      ::Yomikomu.debug{ "compile #{fname} into #{iseq_key}" }
      begin
        iseq = RubyVM::InstructionSequence.compile_file(fname)
        binary = iseq.to_binary(extra_data(fname))
        write_compiled_iseq(fname, iseq_key, binary)
        ::Yomikomu::STATISTICS[:compiled] += 1
        iseq
      rescue SyntaxError, RuntimeError => e
        puts "#{e}: #{fname}"
        nil
      end
    end

    # def remove_compiled_iseq fname; nil; end # should implement at sub classes

    private

    def iseq_key_name fname
      fname
    end

    # should implement at sub classes
    # def compiled_iseq_younger? fname, iseq_key; end
    # def compiled_iseq_exist? fname, iseq_key; end
    # def read_compiled_file fname, iseq_key; end
    # def write_compiled_file fname, iseq_key, binary; end
  end

  class FSStorage < BasicStorage
    def initialize
      super
    end

    def remove_compiled_iseq fname
      iseq_key = iseq_key_name(fname)
      if File.exist?(iseq_key)
        Yomikomu.debug{ "rm #{iseq_key}" }
        File.unlink(iseq_key)
      end
    end

    private

    def iseq_key_name fname
      "#{fname}.yarb" # same directory
    end

    def compiled_iseq_exist? fname, iseq_key
      File.exist?(iseq_key)
    end

    def compiled_iseq_is_younger? fname, iseq_key
      File.mtime(iseq_key) >= File.mtime(fname)
    end

    def read_compiled_iseq fname, iseq_key
      File.binread(iseq_key)
    end

    def write_compiled_iseq fname, iseq_key, binary
      File.binwrite(iseq_key, binary)
    end

    def remove_all_compiled_iseq
      raise "unsupported"
    end
  end

  class FSSGZtorage < FSStorage

  end

  class FS2Storage < FSStorage
    def initialize
      super

      require 'fileutils'
      @dir = Yomikomu.prefix + "files"
      unless File.directory?(@dir)
        FileUtils.mkdir_p(@dir)
      end
    end

    def iseq_key_name fname
      File.join(@dir, fname.gsub(/[^A-Za-z0-9\._-]/){|c| '%02x' % c.ord} + '.yarb') # special directory
    end

    def remove_all_compiled_iseq
      Dir.glob(File.join(@dir, '**/*.yarb')){|path|
        Yomikomu.debug{ "rm #{path}" }
        FileUtils.rm(path)
      }
    end
  end

  module GZFileStorage
    def initialize
      require 'zlib'
      super
    end

    def iseq_key_name fname
      super + '.gz'
    end

    def read_compiled_iseq fname, iseq_key
      Zlib::GzipReader.open(iseq_key){|f|
        f.read
      }
    end

    def write_compiled_iseq fname, iseq_key, binary
      Zlib::GzipWriter.open(iseq_key){|f|
        f.write(binary)
      }
    end
  end

  class FSGZStorage < FSStorage
    include GZFileStorage
  end

  class FS2GZStorage < FS2Storage
    include GZFileStorage
  end

  if YOMIKOMU_USE_MMAP
    require 'mmapped_string'
    Yomikomu.info{ "[RUBY_YOMIKOMU] use mmap" }

    module MMapFile
      def read_compiled_iseq fname, iseq_key
        MmappedString.open(iseq_key)
      end
    end

    class FSStorage
      prepend MMapFile
    end

    class FS2Storage
      prepend MMapFile
    end
  end

  class DBMStorage < BasicStorage
    def initialize
      super
      require 'dbm'
      @db = DBM.open(Yomikomu.prefix + 'db')
    end

    def remove_compiled_iseq fname
      @db.delete fname
    end

    private

    def date_key_name fname
      "date.#{fname}"
    end

    def iseq_key_name fname
      "body.#{fname}"
    end

    def compiled_iseq_exist? fname, iseq_key
      @db.has_key? iseq_key
    end

    def compiled_iseq_is_younger? fname, iseq_key
      date_key = date_key_name(fname)
      if @db.has_key? date_key
        @db[date_key].to_i >= File.mtime(fname).to_i
      end
    end

    def read_compiled_iseq fname, iseq_key
      @db[iseq_key]
    end

    def write_compiled_iseq fname, iseq_key, binary
      date_key = date_key_name(fname)
      @db[iseq_key] = binary
      @db[date_key] = Time.now.to_i
    end
  end

  class FlatFileStorage < BasicStorage
    def initialize
      super
      require 'fileutils'

      index_path = Yomikomu.prefix + 'ff_index'
      data_path  = Yomikomu.prefix + 'ff_data'

      @updated = false

      if File.exist?(index_path)
        open(index_path, 'rb'){|f| @index = Marshal.load(f)}
      else
        @index = {}
        open(data_path, 'w'){} # touch
      end

      @data_file = open(data_path, 'a+b')

      at_exit{
        if @updated
          open(index_path, 'wb'){|f| Marshal.dump(@index, f)}
          Yomikomu.info{'FlatFile: update'}
        end
      }
    end

    def remove_compiled_iseq fname
      raise 'unsupported'
    end

    private

    def compiled_iseq_exist? fname, iseq_key
      @index[iseq_key]
    end

    def compiled_iseq_is_younger? fname, iseq_key
      offset, size, date = @index[iseq_key]
      date.to_i >= File.mtime(fname).to_i
    end

    def read_compiled_iseq fname, iseq_key
      offset, size, date = @index[iseq_key]
      @data_file.pos = offset
      data = @data_file.read(size)
      raise "size is not match" if data.size != size
      data
    end

    def write_compiled_iseq fname, iseq_key, binary
      raise "compiled binary for #{fname} already exists. flatfile does not support overwrite." if compiled_iseq_exist?(fname, iseq_key)

      @data_file.seek 0, IO::SEEK_END
      offset = @data_file.tell
      size = binary.size
      date = Time.now.to_i
      @data_file.write(binary)
      @index[iseq_key] = [offset, size, date]

      @updated = true
    end
  end

  def self.compile_and_store_iseq fname
    STORAGE.compile_and_store_iseq fname
  end

  def self.remove_compiled_iseq fname
    STORAGE.remove_compiled_iseq fname
  end

  def self.remove_all_compiled_iseq
    STORAGE.remove_all_compiled_iseq
  end

  def self.verify_compiled_iseq fname
    STORAGE.verify_compiled_iseq fname
  end

  # select storage
  STORAGE = case storage = ENV['YOMIKOMU_STORAGE']
            when 'fs'
              FSStorage.new
            when 'fsgz'
              FSGZStorage.new
            when 'fs2'
              FS2Storage.new
            when 'fs2gz'
              FS2GZStorage.new
            when 'dbm'
              DBMStorage.new
            when 'flatfile'
              FlatFileStorage.new
            when 'null'
              NullStorage.new
            when nil
              FSStorage.new
            else
              raise "Unknown storage type: #{storage}"
            end

  Yomikomu.info{ "[RUBY_YOMIKOMU] use #{STORAGE.class}" }
end

class RubyVM::InstructionSequence
  def self.load_iseq fname
    ::Yomikomu::STORAGE.load_iseq(fname)
  end
end
