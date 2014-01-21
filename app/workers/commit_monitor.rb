require 'yaml'

class CommitMonitor
  include Sidekiq::Worker

  def self.options
    @options ||= YAML.load_file(Rails.root.join('config/commit_monitor.yml'))
  end

  def self.product
    @product ||= options["product"]
  end

  def self.handlers
    @handlers ||=
      Dir.glob(Rails.root.join("app/workers/commit_monitor_handlers/*.rb")).collect do |f|
        klass = File.basename(f, ".rb").classify
        CommitMonitorHandlers.const_get(klass)
      end
  end

  delegate :handlers, :to => :class

  def perform
    process_branches
  end

  private

  def process_branches
    CommitMonitorRepo.includes(:branches).each do |repo|
      repo.with_git_service do |git|
        repo.branches.each { |branch| process_branch(git, branch) }
      end
    end
  end

  def process_branch(git, branch)
    git.checkout(branch.name)
    git.pull

    commits = git.new_commits(branch.last_commit)
    commits.each do |commit|
      message = git.commit_message(commit)
      process_commit(branch, commit, message)
    end

    branch.update_attributes(:last_commit => commits.last)
  end

  def process_commit(branch, commit, message)
    handlers.each { |h| h.perform_async(branch.id, commit, message) }
  end
end
