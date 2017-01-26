class GithubUsageWorker
  include Sidekiq::Worker
  include Sidetiq::Schedulable
  include SidekiqWorkerMixin
  sidekiq_options :queue => :github_usage, :retry => false

  recurrence { minutely }

  def perform
    if !first_unique_worker?
      logger.info "#{self.class} is already running, skipping"
    else
      GithubUsageTracker.record_datapoint
    end
  end
end
