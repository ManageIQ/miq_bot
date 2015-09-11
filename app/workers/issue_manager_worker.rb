class IssueManagerWorker
  include Sidekiq::Worker
  include Sidetiq::Schedulable
  sidekiq_options :queue => :miq_bot, :retry => false

  recurrence { minutely }

  def perform
    repo_names = Array(Settings.issue_manager.repo_names)
    Repo.where(:name => repo_names).each do |repo|
      process_notifications(repo)
    end
  end

  private

  def process_notifications(repo)
    IssueManager.new(repo.upstream_user, repo.project).process_notifications
  rescue => err
    logger.error err.message
    logger.error err.backtrace.join("\n")
  end
end
