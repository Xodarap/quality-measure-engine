require 'test_helper'

class MapConfigTest < MiniTest::Unit::TestCase

  def test_default_mapconfig
    config = QME::MapReduce::MapConfig.default_config

    assert config.is_a? QME::MapReduce::MapConfig
  end

  def test_configure
    config = QME::MapReduce::MapConfig.configure({
      short_circuit: false,
      enable_rationale: true,
      oid_dictionary: { key: 'value' },
      erraneous_key: 'is ignored'
    })

    expected = QME::MapReduce::MapConfig.new(
      false,
      true,
      false,
      { key: 'value' }
    )

    assert_equal config, expected
  end

end
