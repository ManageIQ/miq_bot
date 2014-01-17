require 'thread'
require 'minigit'

module GitService
  def self.call(path_to_repo, options = {})
    raise "no block given" unless block_given?
    synchronize do
      MiniGit.debug = !!options[:debug]
      yield MiniGit::Capturing.new(path_to_repo)
    end
  end

  private

  def self.mutex
    @mutex ||= Mutex.new
  end

  def self.synchronize
    mutex.synchronize { yield }
  end

  private_class_method :mutex, :synchronize
end
