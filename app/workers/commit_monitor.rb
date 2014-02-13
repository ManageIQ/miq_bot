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

  attr_reader :repo, :git, :branch

  def process_branches
    CommitMonitorRepo.includes(:branches).each do |repo|
      @repo = repo
      repo.with_git_service do |git|
        @git = git
        repo.branches.each do |branch|
          @branch = branch
          process_branch
        end
      end
    end
  end

  def process_branch
    # TODO: Handle PR branch commits.
    return if branch.pull_request?

    git.checkout(branch.name)
    git.pull

    commits = git.new_commits(branch.last_commit)
    commits.each do |commit|
      message = git.commit_message(commit)
      process_commit(commit, message)
    end

    branch.last_checked_on = Time.now.utc
    branch.last_commit     = commits.last if commits.any?
    branch.save!
  end

  def process_commit(commit, message)
    handlers.each { |h| h.perform_async(branch.id, commit, message) }
  end
end
