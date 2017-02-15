class GithubNotificationMonitorWorker
  include Sidekiq::Worker
  sidekiq_options :queue => :miq_bot, :retry => false

  include Sidetiq::Schedulable
  recurrence { minutely }

  include SidekiqWorkerMixin

  def perform
    if !first_unique_worker?
      logger.info "#{self.class} is already running, skipping"
    else
      process_repos
    end
  end

  def process_repos
    enabled_repos.each { |repo| process_repo(repo) }
  end

  def process_repo(repo)
    GithubNotificationMonitor.new(repo.name).process_notifications
  rescue => err
    logger.error err.message
    logger.error err.backtrace.join("\n")
  end
end
