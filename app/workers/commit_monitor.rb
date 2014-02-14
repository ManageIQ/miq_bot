require 'yaml'

class CommitMonitor
  include Sidekiq::Worker

  def self.options
    @options ||= YAML.load_file(Rails.root.join('config/commit_monitor.yml'))
  end

  def self.product
    @product ||= options["product"]
  end

  # commit handlers expect to handle a specific commit at a time.
  #
  # Example: A commit message checker that will check for URLs and act upon them.
  def self.commit_handlers
    @commit_handlers ||= handlers_for(:commit)
  end

  # commit_range handlers expect to handle a range of commits as a group.
  #
  # Example: A style/syntax/warning checker on a PR branch, where we only want
  #   to check the new commits, but as a group, since newer commits may fix
  #   issues in prior commits.
  def self.commit_range_handlers
    @commit_range_handlers ||= handlers_for(:commit_range)
  end

  # branch handlers expect to handle an entire branch at once.
  #
  # Example: A PR branch mergability tester to see if the entire branch can be
  #   merged or not.
  def self.branch_handlers
    @branch_handlers ||= handlers_for(:branch)
  end

  delegate :commit_handlers, :commit_range_handlers, :branch_handlers, :to => :class

  def perform
    process_branches
  end

  private

  def self.handlers_for(type)
    workers_path = Rails.root.join("app/workers")
    Dir.glob(workers_path.join("commit_monitor_handlers/#{type}/*.rb")).collect do |f|
      path = Pathname.new(f).relative_path_from(workers_path).to_s
      path.chomp(".rb").classify.constantize
    end
  end
  private_class_method(:handlers_for)

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
    commit_handlers.each { |h| h.perform_async(branch.id, commit, message) }
  end
end
