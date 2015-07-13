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

      def initialize(params)
        super
        self.enable_logging   = params.fetch(:enable_logging, false)
        self.enable_rationale = params.fetch(:enable_rationale, false)
        self.short_circuit    = params.fetch(:short_circuit, false)
        self.oid_dictionary   = params.fetch(:oid_dictionary, {})
        self.effective_date   = params.fetch(:effective_date)
      end

      def reconfigure(params)
        params.each do |key, value|
          if attribute_names.include? key.to_s
            self[key] = value unless value.nil?
          end
        end
        self
      end
    end
  end
end
