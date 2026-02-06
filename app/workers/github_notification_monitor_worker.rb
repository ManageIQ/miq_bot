class GithubNotificationMonitorWorker
  include Sidekiq::Worker
  sidekiq_options :queue => :miq_bot, :retry => false

  include SidekiqWorkerMixin

  def perform
    if !first_unique_worker?
      logger.info("#{self.class} is already running, skipping")
    else
      process_repos
    end
  end

  def process_repos
    notifications_by_repo_name = GithubService.notifications("all" => false).group_by { |n| n.repository.full_name }
    notifications_by_repo_name.select! { |repo_name, _notifications| enabled_repo_names.include?(repo_name) }
    notifications_by_repo_name.each do |repo_name, notifications|
      process_repo(repo_name, notifications)
      Thread.pass
    end
  end

  def process_repo(repo_name, notifications)
    GithubNotificationMonitor.new(repo_name, notifications).process_notifications
  rescue => err
    logger.error(err.message)
    logger.error(err.backtrace.join("\n"))
  end
end
