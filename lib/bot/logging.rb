require 'logger'

CFME_BOT_LOG_FILE = File.join(File.dirname(__FILE__), 'log/cfme_bot.log')

module Logging
  def self.logger
    @logger ||= Logger.new(CFME_BOT_LOG_FILE)
  end

  def self.logger=(l)
    @logger = l
  end

  def logger
    @logger ||= Logging.logger
  end

  def logger=(l)
    @logger = l
  end
end
