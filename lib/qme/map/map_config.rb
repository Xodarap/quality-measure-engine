module QME
  module MapReduce
    MapConfig = Struct.new(
      :enable_logging,
      :enable_rationale,
      :short_circuit,
      :oid_dictionary,
      :effective_date
    )

    class << MapConfig
      def default_config
        new(false, false, false, {}, nil)
      end

      def configure(params)
        default_config.tap do |config|
          params.each do |key, value|
            if config.members.include? key
              config[key] = value
            end
          end
        end
      end
    end
  end
end
