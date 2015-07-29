require "bot/issue_manager"

class IssueManagerWorker
  include Sidekiq::Worker
  include Sidetiq::Schedulable
  sidekiq_options :queue => :miq_bot, :retry => false

  recurrence { minutely }

  attr_reader :repo_names

  def perform
    @repo_names = Settings.issue_manager.repo_names

    if repo_names.blank?
      logger.info "No repos enabled.  Skipping."
      return
    end

    CommitMonitorRepo.where(:name => repo_names).each do |repo|
      process_notifications(repo)
    end
  end

  private

  def process_notifications(repo)
    IssueManager.new(repo.upstream_user, repo.name).process_notifications
  rescue => err
    logger.error err.message
    logger.error err.backtrace.join("\n")
  end
end
