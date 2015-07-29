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

    repos = CommitMonitorRepo.where(:name => repo_names)
    issue_managers = repos.collect { |r| IssueManager.new(r.upstream_user, r.name) }
    issue_managers.each do |issue_manager|
      with_error_handling { issue_manager.process_notifications }
    end
  end

  def with_error_handling
    yield
  rescue => e
    logger.error e.message
    logger.error e.backtrace.join("\n")
  end
end
