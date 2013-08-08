#!/usr/bin/env ruby

require 'logger'
require_relative './issue_manager'

CFME_BOT_LOG_FILE = File.join(File.dirname(__FILE__), '/cfme_bot.log')
SLEEPTIME = 5


def self.logger
  @logger ||= Logger.new(CFME_BOT_LOG_FILE)
end

def self.logger=(l)
  @logger = l
end

def logger
  self.class.logger
end

issue_manager = IssueManager.new

loop do
  begin
    issue_manager.get_notifications
  rescue =>err
    logger.error ("ERROR: #{err.message} \n #{err.backtrace} \n")
  end
  sleep(SLEEPTIME)
end
