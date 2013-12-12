require 'thread'

module MiniGitMutex
  def self.mutex
    @mutex ||= Mutex.new
  end

  def self.synchronize(&block)
    mutex.synchronize(&block)
  end
end
