$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

require 'tmpdir'

tmpdir = Dir.mktmpdir('yomikomu')
ENV['YOMIKOMU_STORAGE_DIR'] = tmpdir

require 'yomikomu'
Yomikomu.storage = :fs2

require 'minitest/autorun'
