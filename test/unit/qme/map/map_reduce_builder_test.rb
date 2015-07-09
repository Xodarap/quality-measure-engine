require 'test_helper'

class MapReduceBuilderTest < Minitest::Test
  include QME::DatabaseAccess

  def setup
    collection_fixtures(get_db(), 'measures')
    @measure = QME::QualityMeasure.where({"nqf_id" => '0043'}).first
    @map_config = QME::MapReduce::MapConfig.configure(effective_date: Time.gm(2010, 9, 19).to_i)
    load_system_js
  end

  def test_extracting_measure_metadata
    measure = QME::MapReduce::Builder.new(get_db(), @measure, @map_config)
    assert_equal '0043', measure.id
  end

  def test_extracting_parameters
    time = Time.gm(2010, 9, 19).to_i
    measure = QME::MapReduce::Builder.new(get_db(), @measure, @map_config)
    assert_equal 1, measure.params.size
    assert measure.params.keys.include?('effective_date')
    assert_equal time, measure.params['effective_date']
  end
end
