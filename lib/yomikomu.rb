require "yomikomu/version"

module Yomikomu
  STATISTICS = Hash.new(0)

  unless yomu_dir = ENV['YOMIKOMU_STORAGE_DIR']
    yomu_dir = File.expand_path("~/.ruby_binaries")
    unless File.exist?(yomu_dir)
      Dir.mkdir(yomu_dir)
    end
  end
  YOMIKOMU_PREFIX = "#{yomu_dir}/cb."
  YOMIKOMU_AUTO_COMPILE = ENV['YOMIKOMU_AUTO_COMPILE'] == 'true'

  if $VERBOSE
    def self.info
      STDERR.puts "[YOMIKOMU:INFO] (pid:#{Process.pid}) #{yield}"
    end
    at_exit{
      STDERR.puts "[YOMIKOMU:INFO] (pid:#{Process.pid}) " +
                  ::Yomikomu::STATISTICS.map{|k, v| "#{k}: #{v}"}.join(' ,')
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

    def compile_and_store_iseq fname, iseq_key = iseq_key_name(fname)
      ::Yomikomu::STATISTICS[:compiled] += 1
      ::Yomikomu.debug{ "[RUBY_COMPILED_FILE] compile #{fname} into #{iseq_key}" }
      iseq = RubyVM::InstructionSequence.compile_file(fname)

      binary = iseq.to_binary(extra_data(fname))
      write_compiled_iseq(fname, iseq_key, binary)
      iseq
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
      require 'fileutils'
      @dir = YOMIKOMU_PREFIX + "files"
      unless File.directory?(@dir)
        FileUtils.mkdir_p(@dir)
      end
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

  class FS2Storage < FSStorage
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

  class DBMStorage < BasicStorage
    def initialize
      require 'dbm'
      @db = DBM.open(YOMIKOMU_PREFIX+'db')
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
  STORAGE = case ENV['YOMIKOMU_STORAGE']
            when 'dbm'
              DBMStorage.new
            when 'fs'
              FSStorage.new
            when 'fs2'
              FS2Storage.new
            when 'null'
              NullStorage.new
            else
              FSStorage.new
            end

  Yomikomu.info{ "[RUBY_YOMIKOMU] use #{STORAGE.class}" }
end

class RubyVM::InstructionSequence
  def self.load_iseq fname
    ::Yomikomu::STORAGE.load_iseq(fname)
  end
end
