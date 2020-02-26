module Schedulers
  class StaleIssueMarker
    include Sidekiq::Worker
    sidekiq_options :queue => :miq_bot_glacial, :retry => false

    include Sidetiq::Schedulable
    recurrence { weekly.day(:monday) }

    include SidekiqWorkerMixin

    def perform
      StaleIssueMarker.perform_async
    end
  end
end
