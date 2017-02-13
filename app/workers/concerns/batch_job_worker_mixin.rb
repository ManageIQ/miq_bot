module BatchJobWorkerMixin
  extend ActiveSupport::Concern

  module ClassMethods
    def perform_batch_async(*args)
      BatchJob.perform_async(batch_workers, args,
        :on_complete_class => self,
        :on_complete_args  => args,
        :expires_at        => 5.minutes.from_now
      )
    end
  end

  attr_reader :batch_job

  def find_batch_job(batch_job_id)
    @batch_job = BatchJob.where(:id => batch_job_id).first

    if @batch_job.nil?
      logger.warn("BatchJob #{batch_job_id} no longer exists.  Skipping.")
      return false
    end

    true
  end

  def complete_batch_job
    batch_job.destroy
  end
  alias skip_batch_job complete_batch_job
end
