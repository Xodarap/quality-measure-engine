require 'erb'
require 'ostruct'

module QME
  module MapReduce
    # Builds Map and Reduce functions for a particular measure
    class Builder
      attr_reader :id

      # Utility class used to supply a binding to Erb
      class Context < OpenStruct
        def initialize(db, config)
          super(config.attributes)
          @db = db
        end

        def get_binding # rubocop:disable Style/AccessorMethodName
          binding
        end

        # Inserts any library code into the measure JS. JS library code is
        # loaded from three locations: the js directory of the
        # quality-measure-engine project, the js sub-directory of the current
        # directory (e.g. measures/js), and the bundles collection of the
        # current database (used by the Rails Web application).
        def init_js_frameworks
          result = ''
          result << 'if (typeof(map)=="undefined") {'
          result << "\n"
          @db['bundles'].find.each do |bundle|
            (bundle['extensions'] || []).each do |ext|
              result << "#{ext}();\n"
            end
          end
          result << "}\n"
          result
        end
      end

      # Create a new Builder
      def initialize(db, measure, map_config = MapConfig.default_config)
        @map_config = map_config
        @effective_date = map_config.effective_date
        @measure = measure
        @id = @measure['id']
        @db = db

        # if the map function is specified then replace any erb templates with
        # their values taken from the supplied params
        # always true for actual measures, not always true for unit tests
        return if @measure.map_fn.blank?
        template = ERB.new(@measure.map_fn)
        context = Context.new(@db, @map_config)
        @measure.map_fn = template.result(context.get_binding)
      end

      # Get the map function for the measure
      # @return [String] the map function
      def map_function
        @measure.map_fn
      end

      # Get the reduce function for the measure, this is a simple
      # wrapper for the reduce utility function specified in
      # map-reduce-utils.js
      # @return [String] the reduce function
      def finalize_function
        reporting_period_start = Time.at(@effective_date).prev_year.to_i
        reduce =
        "function (key, value) {
          var patient = value;
          patient.measure_id = \"#{@measure['id']}\";\n"
        if @measure.sub_id
          reduce += "  patient.sub_id = \"#{@measure.sub_id}\";\n"
        end
        if @measure.nqf_id
          reduce += "  patient.nqf_id = \"#{@measure.nqf_id}\";\n"
        end

        reduce += "patient.effective_date = #{@effective_date};
                   if (patient.provider_performances) {
                     var tmp = [];
                     for(var i=0; i<patient.provider_performances.length; i++) {
                       var value = patient.provider_performances[i];
                       if (
                        // Early Overlap
                        ((value['start_date'] <= #{reporting_period_start} || value['start_date'] == null) && (value['end_date'] > #{reporting_period_start})) ||
                        // Late Overlap
                        ((value['start_date'] < #{@effective_date}) && (value['end_date'] >= #{@effective_date} || value['end_date'] == null)) ||
                        // Full Overlap
                        ((value['start_date'] <= #{reporting_period_start} || value['start_date'] == null) && (value['end_date'] >= #{@effective_date} || value['end_date'] == null)) ||
                        // Full Containment
                        (value['start_date'] > #{reporting_period_start} && value['end_date'] < #{@effective_date})
                       )
                       tmp.push(value);
                     }
                     if (tmp.length > 0) {
                        patient.provider_performances = tmp;
                     } else {
                        sortedProviders = _.sortBy(patient.provider_performances, function(performance){return performance['end_date']});
                        patient.provider_performances = [_.last(sortedProviders)];
                     }
                   }
                   return patient;}"

        reduce
      end
    end
  end
end
