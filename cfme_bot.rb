require_relative 'issue_manager'

CFME_BOT_YAML_FILE  = File.join(File.dirname(__FILE__), '/cfme_bot.yml')
SLEEPTIME = 15

class CfmeBot
  include Logging

  def initialize
    @repo_names = load_yaml_file
  end

  def load_yaml_file
    begin
      @repo_names = YAML.load_file(CFME_BOT_YAML_FILE)
    rescue Errno::ENOENT
      logger.error ("#{Time.now} #{CFME_BOT_YAML_FILE} is missing, exiting...")
      exit 1
    end
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

CfmeBot.new.run
