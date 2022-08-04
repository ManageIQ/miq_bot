module Schedulers
  class StaleIssueMarker
    include Sidekiq::Worker
    sidekiq_options :queue => :miq_bot_glacial, :retry => false

    include SidekiqWorkerMixin

    def perform
      if !first_unique_worker?
        logger.info "#{self.class} is already running, skipping"
      else
        process_stale_issues
      end
    end

    def process_stale_issues
      StaleIssueMarker.perform_async
    end
  end
end
