require 'test_helper'

class MapConfigTest < MiniTest::Unit::TestCase

  def test_default_mapconfig
    config = QME::MapReduce::MapConfig.default_config

    assert config.is_a? QME::MapReduce::MapConfig
  end

end
