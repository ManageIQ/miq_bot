require "bot/issue_manager"

class IssueManagerWorker
  include Sidekiq::Worker
  include Sidetiq::Schedulable

  recurrence { hourly.minute_of_hour(0, 15, 30, 45) }

  attr_reader :repo_names, :issue_managers

  def initialize
    @repo_names = Settings.issue_manager.repo_names
    fail "No repos defined" if repo_names.nil? || repo_names.empty?
    @issue_managers = repo_names.collect { |repo_name| IssueManager.new(repo_name) }
    super
  end

  def perform
    issue_managers.each do |issue_manager|
      with_error_handling { issue_manager.get_notifications }
    end
  end

  def with_error_handling(&block)
    block.call
  rescue => e
    logger.error "ERROR: #{e.message}\n#{e.backtrace}\n"
  end
end
