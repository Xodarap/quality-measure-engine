module QME
  module MapReduce
    class MapConfig

      include Mongoid::Document

      field :enable_logging
      field :enable_rationale
      field :short_circuit
      field :oid_dictionary
      field :effective_date

      embedded_in :quality_report

      class << self
        def default_config
          new({
            enable_logging: false,
            enable_rationale: false,
            short_circuit: false,
            oid_dictionary: {},
            effective_date: nil
          })
        end

        def configure(params)
          default_config.tap do |config|
            params.each do |key, value|
              if config.attribute_names.include? key.to_s
                config[key] = value
              end
            end
          end
        end
      end

    end
  end
end
