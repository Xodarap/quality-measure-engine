require 'test_helper'

class MapConfigTest < Minitest::Test
  def test_error_if_no_effective_date
    assert_raises KeyError do
      QME::MapReduce::MapConfig.new(short_circuit: false)
    end
  end

  def test_defaults
    config = QME::MapReduce::MapConfig.new(
      short_circuit: false,
      enable_rationale: true,
      effective_date: 123
    )

    assert config.enable_rationale
    assert !config.enable_logging
    assert_equal config.oid_dictionary, {}
  end

  def test_reconfigure
    config = QME::MapReduce::MapConfig.new(
      short_circuit: false,
      enable_rationale: true,
      effective_date: 123
    )

    config.reconfigure(short_circuit: true)

    assert config.short_circuit
  end
end
