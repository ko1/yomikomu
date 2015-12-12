require 'test_helper'

class YomikomuTest < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::Yomikomu::VERSION
  end

  def test_compile_file
    assert_equal 0, ::Yomikomu::STATISTICS[:loaded]
    assert_equal 0, ::Yomikomu::STATISTICS[:compiled]
    ignored = ::Yomikomu::STATISTICS[:ignored]

    Yomikomu::compile_and_store_iseq File.join(__dir__, 'x.rb')
    assert_equal 1, ::Yomikomu::STATISTICS[:compiled]

    load_file = File.join(__dir__, 'x.rb')

    load load_file

    assert_equal("hello world", yomikomi_test_hello("world"))
    assert_equal 1, ::Yomikomu::STATISTICS[:loaded]
    assert_equal 1, ::Yomikomu::STATISTICS[:compiled]

    Yomikomu::remove_all_compiled_iseq
    load load_file

    assert_equal("hello world", yomikomi_test_hello("world"))
    assert_equal 1, ::Yomikomu::STATISTICS[:loaded]
    assert_equal 1, ::Yomikomu::STATISTICS[:compiled]

    Yomikomu::compile_and_store_iseq File.join(__dir__, 'x.rb')
    assert_equal 2, ::Yomikomu::STATISTICS[:compiled]

    Yomikomu::remove_compiled_iseq load_file
    load load_file

    assert_equal("hello world", yomikomi_test_hello("world"))
    assert_equal 1, ::Yomikomu::STATISTICS[:loaded]
    assert_equal 2, ::Yomikomu::STATISTICS[:compiled]
  end
end
