require 'test_helper'

class MapReduceBuilderTest < Minitest::Test
  include QME::DatabaseAccess

  def setup
    collection_fixtures(get_db(), 'measures')
    @measure = QME::QualityMeasure.where({"nqf_id" => '0043'}).first
    config = { effective_date: Time.gm(2010, 9, 19).to_i }
    @map_config = QME::MapReduce::MapConfig.default_config.configure(config)
    load_system_js
  end

  def test_extracting_measure_metadata
    measure = QME::MapReduce::Builder.new(get_db(), @measure, @map_config)
    assert_equal '0043', measure.id
  end
end
