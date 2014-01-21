require 'thread'
require 'minigit'

class GitService
  def self.call(*args)
    raise "no block given" unless block_given?
    synchronize { yield new(*args) }
    nil
  end

  attr_reader :path_to_repo

  def initialize(path_to_repo)
    @path_to_repo = path_to_repo
    service # initialize the service
  end

  def service
    @service ||= begin
      MiniGit.debug = true
      MiniGit::Capturing.new(File.expand_path(path_to_repo))
    end
  end

  def method_missing(method_name, *args)
    service.send(method_name, *args)
  end

  def respond_to_missing?(*args)
    service.respond_to?(*args)
  end

  def new_commits(since_commit)
    rev_list({:reverse => true}, "#{since_commit}..HEAD").chomp.split("\n")
  end

  def commit_message(commit)
    log({:pretty => "fuller"}, "--stat", "-1", commit)
  end

  private

  def self.mutex
    @mutex ||= Mutex.new
  end

  def self.synchronize
    mutex.synchronize { yield }
  end

  private_class_method :mutex, :synchronize

  # Hide new in favor of using .call with block to force synchronization
  private_class_method :new
end
