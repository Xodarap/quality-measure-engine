require 'test_helper'

class MapConfigTest < Minitest::Test

  def test_default_mapconfig
    config = QME::MapReduce::MapConfig.default_config

    assert config.is_a? QME::MapReduce::MapConfig
  end

  def test_configure
    config = QME::MapReduce::MapConfig.default_config
    new_config = config.configure({
      short_circuit: false,
      enable_rationale: true,
      oid_dictionary: { key: 'value' },
      erraneous_key: 'is ignored'
    })

    expected = {
      'enable_logging' => false,
      'enable_rationale' => true,
      'short_circuit' => false,
      'oid_dictionary' => { key: 'value' },
      'effective_date' => nil
    }

    assert_equal new_config.attributes.except('_id'), expected
  end

end
