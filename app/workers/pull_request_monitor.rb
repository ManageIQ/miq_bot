class PullRequestMonitor
  include Sidekiq::Worker
  include Sidetiq::Schedulable
  include MiqToolsServices::SidekiqWorkerMixin
  sidekiq_options :queue => :miq_bot_glacial, :retry => false

  recurrence { hourly.minute_of_hour(0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55) }

  def perform
    if !first_unique_worker?
      logger.info "#{self.class} is already running, skipping"
    else
      Repo.includes(:branches).each do |repo|
        # TODO: Need a better check for repos that *can* have PRs
        next unless repo.upstream_user

        RepoProcessor.process(repo)
      end
    end
  end
end
