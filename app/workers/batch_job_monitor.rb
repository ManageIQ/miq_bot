class BatchJobMonitor
  include Sidekiq::Worker
  include Sidetiq::Schedulable
  include MiqToolsServices::SidekiqWorkerMixin

  sidekiq_options :queue => :miq_bot, :retry => false

  recurrence { minutely }

  def perform
    if !first_unique_worker?
      logger.info "#{self.class} is already running, skipping"
    else
      perform_check
    end
  end

  def perform_check
    BatchJob.all.each(&:check_complete)
  end
end
