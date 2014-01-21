require 'thread'
require 'minigit'

module GitService
  def self.call(path_to_repo)
    raise "no block given" unless block_given?
    synchronize do
      MiniGit.debug = true
      yield MiniGit::Capturing.new(path_to_repo)
    end
  end

  def self.new_commits(git, since_commit)
    git.rev_list({:reverse => true}, "#{since_commit}..HEAD").chomp.split("\n")
  end

  def self.commit_message(git, commit)
    git.log({:pretty => "fuller"}, "--stat", "-1", commit)
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
