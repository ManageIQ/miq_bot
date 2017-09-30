module Schedulers
  class StaleIssueMarker
    include Sidekiq::Worker
    sidekiq_options :queue => :miq_bot_glacial, :retry => false

    include Sidetiq::Schedulable
    recurrence { weekly.day(:monday) }

    include SidekiqWorkerMixin

    def perform
      fq_repo_names.each do |name|
        ::StaleIssueMarker.perform_async(name)
      end
    end

    private

    def fq_repo_names
      Settings.stale_issue_marker.enabled_repos
    end
  end
end
