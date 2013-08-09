#!/usr/bin/env ruby

require 'logger'
require_relative './issue_manager'

CFME_BOT_LOG_FILE = File.join(File.dirname(__FILE__), '/cfme_bot.log')
CFME_BOT_YAML_FILE  = File.join(File.dirname(__FILE__), '/cfme_bot.yml')

SLEEPTIME = 5


class CfmeBot

  def initialize
    @repos = load_yaml_file
  end

  def self.logger
    @logger ||= Logger.new(CFME_BOT_LOG_FILE)
  end

  def self.logger=(l)
    @logger = l
  end

  def logger
    self.class.logger
  end

  def load_yaml_file
    begin
      @repos = YAML.load_file(CFME_BOT_YAML_FILE)
    rescue Errno::ENOENT
      logger.error ("#{Time.now} #{CFME_BOT_YAML_FILE} is missing, exiting...")
      exit 1
    end 
  end

  def run
    loop do
      @repos.each do |repo|
        issue_manager = IssueManager.new(repo)
        begin
          issue_manager.get_notifications
        rescue =>err
          logger.error ("ERROR: #{err.message} \n #{err.backtrace} \n")
        end
      end
      sleep(SLEEPTIME)
    end
  end
end

CfmeBot.new.run 

