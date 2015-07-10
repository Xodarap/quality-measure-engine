module QME

  class QualityReportResult
    include Mongoid::Document
    include Mongoid::Timestamps

    field :population_ids, type: Hash
    field :IPP, type: Integer
    field :DENOM, type: Integer
    field :NUMER, type: Integer
    field :antinumerator, type: Integer
    field :DENEX, type: Integer
    field :DENEXCEP, type: Integer
    field :MSRPOPL, type: Integer
    field :OBSERV, type: Float
    field :supplemental_data, type: Hash

    embedded_in :quality_report, inverse_of: :result
  end
  # A class that allows you to create and obtain the results of running a
  # quality measure against a set of patient records.
  class QualityReport

    include Mongoid::Document
    include Mongoid::Timestamps
    include Mongoid::Attributes::Dynamic
    store_in collection: 'query_cache'

    field :nqf_id, type: String
    field :npi, type: String
    field :calculation_time, type: Time
    field :status, type: Hash, default: {"state" => "unknown", "log" => []}
    field :measure_id, type: String
    field :sub_id, type: String
    field :effective_date, type: Integer
    field :filters, type: Hash
    field :prefilter, type: Hash
    embeds_one :result, class_name: "QME::QualityReportResult", inverse_of: :quality_report
    embeds_one :map_config, class_name: 'QME::MapReduce::MapConfig'
    index "measure_id" => 1
    index "sub_id" => 1
    index "filters.provider_performances.provider_id" => 1

    POPULATION = 'IPP'
    DENOMINATOR = 'DENOM'
    NUMERATOR = 'NUMER'
    EXCLUSIONS = 'DENEX'
    EXCEPTIONS = 'DENEXCEP'
    MSRPOPL = 'MSRPOPL'
    OBSERVATION = 'OBSERV'
    ANTINUMERATOR = 'antinumerator'
    CONSIDERED = 'considered'

    RACE = 'RACE'
    ETHNICITY = 'ETHNICITY'
    SEX ='SEX'
    POSTAL_CODE = 'POSTAL_CODE'
    PAYER   = 'PAYER'
    CMS_PAYER = 'CMS_PAYER'

    after_create :configure

    # Accessors for the various status['state'] flags, similar API to
    # ActiveRecord::Enum.

    def queued!
      self.status['state'] = 'queued'
      save
    end

    def queued?
      self.status['state'] == 'queued'
    end

    def staged!
      self.status['state'] = 'staged'
      save
    end

    def staged?
      self.status['state'] == 'staged'
    end

    def completed!
      self.status['state'] = 'completed'
      save
    end

    def completed?
      self.status['state'] == 'completed'
    end

    alias_method :calculated?, :completed?

    # Determines whether the patient mapping for the quality report has been
    # completed
    def patients_cached?
      QME::QualityReport.where(measure_id: measure_id, sub_id: sub_id, effective_date: effective_date, "status.state" => "completed").exists?
    end


    # Determines whether the patient mapping for the quality report has been
    # queued up by another quality report or if it is currently running
    def calculation_queued_or_running?
      QME::QualityReport.where(measure_id: measure_id, sub_id: sub_id, effective_date: effective_date).nin("status.state" =>["unknown","staged"]).exists?
    end

    def config
      map_config ||= QME::MapReduce::MapConfig.default_config
    end

    def configure(params = {})
      params[:effective_date] = effective_date
      if measure.present?
        oid_dictionary = OidHelper.generate_oid_dictionary(measure['oids'])
        params[:oid_dictionary] = oid_dictionary
      end
      config.configure(params)
    end

    def calculate_now
      queued!
      QME::MapReduce::MeasureCalculationJob.new(id).perform
    end

    # Kicks off a background job to calculate the measure
    # @return a unique id for the measure calculation job
    def calculate
      if patients_cached?
        enque_job(:rollup)
      elsif calculation_queued_or_running?
        stage_rollup!
      else
        enque_job(:calculation)
      end
    end

    def enque_job(queue)
      queued!
      job = QME::MapReduce::MeasureCalculationJob.new(id)
      Delayed::Job.enqueue(job, { queue: queue })
    end

    def stage_rollup!
      staged!
      rollup = {
        measure_id: measure_id,
        sub_id: sub_id,
        effective_date: effective_date,
        quality_report_id: id
      }
      mongo_session["rollup_buffer"].insert(rollup)
    end

    def patient_results
      QME::PatientCache.where(patient_cache_matcher)
    end

    def measure
      QME::QualityMeasure.where(hqmf_id: measure_id, sub_id: sub_id).first
    end

    def patient_result(patient_id = nil)
      query = patient_cache_matcher
      if patient_id
        query['value.medical_record_id'] = patient_id
      end
      QME::PatientCache.where(query).first()
    end


    def patient_cache_matcher
      match = {'value.measure_id'       => measure_id,
               'value.sub_id'           => sub_id,
               'value.effective_date'   => effective_date,
               'value.manual_exclusion' => {'$in' => [nil, false]}}

      if filters
        if filters['races'].present?
          match['value.race.code'] = {'$in' => filters['races']}
        end
        if filters['ethnicities'].present?
          match['value.ethnicity.code'] = {'$in' => filters['ethnicities']}
        end
        if filters['genders'].present?
          match['value.gender'] = {'$in' => filters['genders']}
        end
        if filters['providers'].present?
          providers = filters['providers'].map { |pv| BSON::ObjectId.from_string(pv) }
          match['value.provider_performances.provider_id'] = {'$in' => providers}
        end
        if filters['languages'].present?
          match["value.languages"] = {'$in' => filters['languages']}
        end
      end
      match
    end

    def queue_staged_rollups
      query = { measure_id: measure_id,
                sub_id: sub_id,
                effective_date: effective_date }
      rollups = mongo_session["rollup_buffer"].find(query)
      rollups.each do |rollup|
        qr = QME::QualityReport.find(rollup["quality_report_id"])
        qr.enque_job(:rollup)
      end
      rollups.remove_all
    end

    # Removes the cached results for the patient with the supplied id and
    # recalculates as necessary
    def self.update_patient_results(id)
      # TODO: need to wait for any outstanding calculations to complete and then prevent
      # any new ones from starting until we are done.

      # drop any cached measure result calculations for the modified patient
     QME::PatientCache.where('value.medical_record_id' => id).destroy()

      # get a list of cached measure results for a single patient
      sample_patient = QME::PatientCache.where({}).first
      if sample_patient
        cached_results = QME::PatientCache.where({'value.patient_id' => sample_patient['value']['patient_id']})

        # for each cached result (a combination of measure_id, sub_id, and effective_date)
        cached_results.each do |measure|
          # recalculate patient_cache value for modified patient
          value = measure['value']
          map = QME::MapReduce::Executor.new(value['measure_id'], value['sub_id'],
            'effective_date' => value['effective_date'])
          map.map_record_into_measure_groups(id)
        end
      end

      # remove the query totals so they will be recalculated using the new results for
      # the modified patient
      destroy_all
    end

    def self.find_or_create(measure_id, sub_id, parameter_values)
      @parameter_values = parameter_values
      @parameter_values[:filters] = normalize_filters(@parameter_values[:filters])
      query = { measure_id: measure_id, sub_id: sub_id }
      query.merge! @parameter_values
      find_or_create_by(query)
    end

    # make sure all filter id arrays are sorted
    def self.normalize_filters(filters)
      unless filters.nil?
        filters.each do |key, value|
          if value.is_a? Array
            value.sort_by! {|v| (v.is_a? Hash) ? "#{v}" : v}
          end
        end
      end
    end

    protected

     # In the older version of QME QualityReport was not treated as a persisted object. As
     # a result anytime you wanted to get the cached results for a calculation you would create
     # a new QR object which would then go to the db and see if the calculation was performed or
     # not yet and then return the results.  Now that QR objects are persisted you need to go through
     # the find_or_create by method to ensure that duplicate entries are not being created.  Protecting
     # this method causes an exception to be thrown for anyone attempting to use this version of QME with the
     # sematics of the older version to highlight the issue.
    def initialize(attrs = nil)
      super(attrs)
    end
  end
end
