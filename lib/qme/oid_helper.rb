module QME
  class OidHelper
    def self.generate_oid_dictionary(oids)
      valuesets = HealthDataStandards::SVS::ValueSet.in(oid: oids)
      {}.tap do |js|
        valuesets.each do |vs|
          oid = vs['oid']
          js[oid] ||= {}
          vs['concepts'].each do |con|
            name = con['code_system_name']
            code = con['code'].downcase
            js[oid][name] ||= []
            unless js[oid][name].include?(code)
              js[oid][name] << code
            end
          end
        end
      end.to_json
    end

    def self.gen2(oids)
      valuesets = HealthDataStandards::SVS::ValueSet.in(oid: oids)
      map = %Q{
        function() {
          var oid = this.oid;
          this.concepts.forEach(function(item){
            emit({oid: oid, name: item.code_system_name}, item.code.toLowerCase());
          });
        }
      }

      reduce = %Q{
        function(key, values) {
          return { vals: Array.unique(values) };
        }
      }

      mg = valuesets.map_reduce(map, reduce).out(inline: true)
      {}.tap do |equiv|
        mg.each do |x|
          oid = x['_id']['oid']
          name = x['_id']['name']
          codes = x['value']['vals']
          if codes.nil?
            codes = [x['value']]
          end
          equiv[oid] ||= {}
          equiv[oid][name] = codes
        end
      end.to_json
    end
  end
end
