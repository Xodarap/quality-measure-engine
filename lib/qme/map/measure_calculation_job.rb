module QME
  module MapReduce
    # A delayed_job that allows for measure calculation by a delayed_job worker. Can be created as follows:
    #
    #     Delayed::Job.enqueue QME::MapRedude::MeasureCalculationJob.new(quality_report, :effective_date => 1291352400, :test_id => xyzzy)
    #
    # MeasureCalculationJob will check to see if a measure has been calculated before running the calculation. It will do this by
    # checking the status of the quality report that this calculation job was created with.
    #
    # When a measure needs calculation, the job will create a QME::MapReduce::Executor and interact with it to calculate
    # the report.
    class MeasureCalculationJob
      attr_accessor :quality_report

      def initialize(qr_id)
        @quality_report = QME::QualityReport.find(qr_id)
      end

      def perform
        unless @quality_report.calculated?
          map = QME::MapReduce::Executor.new(@quality_report)
          unless @quality_report.patients_cached?
            tick('Starting MapReduce')
            map.map_records_into_measure_groups(@quality_report['prefilter'])
            tick('MapReduce complete')
          end

          tick('Calculating group totals')
          result = map.count_records_in_measure_groups
          @quality_report.update_attribute(:result, result)
          completed(completion_summary(result))
          @quality_report.queue_staged_rollups
        end
        @quality_report
      end

      def completed(message)
        @quality_report.status["state"] = "completed"
        @quality_report.status["log"] << message
        @quality_report.calculation_time = Time.now
        @quality_report.save
      end

      def tick(message)
        @quality_report.status["state"] = "calculating"
        @quality_report.status["log"] << message
        @quality_report.save
      end

      def enqueue(job)
        @quality_report.status = {"state" => "queued", "log" => ["Queued at #{Time.now}"], "job_id" => job.id}
        @quality_report.save
      end


      def error(job, exception)
        @quality_report.status["state"] = "error"
        @quality_report.status["log"] << exception.to_s
        @quality_report.save
      end

      def failure(job)
        @quality_report.status["state"] = "failed"
        @quality_report.status["log"] << "Failed at #{Time.now}"
        @quality_report.save
      end

      def after(job)
        @quality_report.status.delete("job_id")
        @quality_report.save
      end

      # Returns the status of a measure calculation job
      # @param job_id the id of the job to check on
      # @return [Symbol] Will return the status: :complete, :queued, :running, :failed
      def self.status(job_id)
        job = Delayed::Job.where(_id: job_id).first
        if job.nil?
          # If we can't find the job, we assume that it is complete
          :complete
        elsif job.locked_at.nil?
          :queued
        elsif job.failed?
          :failed
        else
          :running
        end
      end

      private

      def completion_summary(result)
        "#{@measure_id}#{@sub_id}: p#{result[QME::QualityReport::POPULATION]}, d#{result[QME::QualityReport::DENOMINATOR]}, n#{result[QME::QualityReport::NUMERATOR]}, excl#{result[QME::QualityReport::EXCLUSIONS]}, excep#{result[QME::QualityReport::EXCEPTIONS]}"
      end

    end
  end
end
