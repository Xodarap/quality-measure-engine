module QME
  module MapReduce
    MapConfig = Struct.new(
      :enable_logging,
      :enable_rationale,
      :short_circuit,
      :oid_dictionary
    )

    class << MapConfig
      def default_config
        new(false, false, false, {})
      end
    end
  end
end
