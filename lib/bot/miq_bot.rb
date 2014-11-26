require_relative 'issue_manager'

class MiqBot
  include Logging

  SLEEPTIME = 15

  def initialize
    @repo_names = Settings.issue_manager.repo_names
    raise "No repos defined" if @repo_names.nil? || @repo_names.empty?
  end

  def run
    loop do
      handle_issue_managers
      sleep(SLEEPTIME)
    end
  end

  private

  def issue_managers
    @issue_managers ||= @repo_names.collect { |r| IssueManager.new(r) }
  end

  def handle_issue_managers
    issue_managers.each do |im|
      begin
        im.get_notifications
      rescue =>err
        logger.error ("ERROR: #{err.message} \n #{err.backtrace} \n")
      end
    end
  end
end

MiqBot.new.run
