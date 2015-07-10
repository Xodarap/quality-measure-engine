module QME
  module MapReduce
    class MapConfig
      include Mongoid::Document

      field :enable_logging
      field :enable_rationale
      field :short_circuit
      field :oid_dictionary
      field :effective_date

      embedded_in :quality_report, class_name: 'QME::MapReduce::QualityReport'

      def configure(params)
        params.each do |key, value|
          if attribute_names.include? key.to_s
            self[key] = value unless value.nil?
          end
        end
        self
      end

      def self.default_config
        new(
          enable_logging: false,
          enable_rationale: false,
          short_circuit: false,
          oid_dictionary: {},
          effective_date: nil
        )
      end
    end
  end
end
