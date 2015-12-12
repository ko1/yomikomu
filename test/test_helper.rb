$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

require 'tmpdir'

tmpdir = Dir.mktmpdir('yomikomu')
ENV['YOMIKOMU_STORAGE_DIR'] = tmpdir
ENV['YOMIKOMU_STORAGE'] = 'fs2'
require 'yomikomu'
require 'minitest/autorun'
