class GithubNotificationMonitorWorker
  include Sidekiq::Worker
  include Sidetiq::Schedulable
  include MiqToolsServices::SidekiqWorkerMixin
  sidekiq_options :queue => :miq_bot, :retry => false

  recurrence { minutely }

  def perform
    if !first_unique_worker?
      logger.info "#{self.class} is already running, skipping"
    else
      process_repos
    end
  end

  private

  def process_repos
    repo_names = Array(Settings.github_notification_monitor.repo_names)
    Repo.where(:name => repo_names).each do |repo|
      process_notifications(repo)
    end
  end

  def process_notifications(repo)
    GithubNotificationMonitor.build(repo.upstream_user, repo.project).process_notifications
  rescue => err
    logger.error err.message
    logger.error err.backtrace.join("\n")
  end
end
