class CommitMonitor
  include Sidekiq::Worker
  sidekiq_options :queue => :miq_bot_glacial, :retry => false

  include Sidetiq::Schedulable
  recurrence { hourly.minute_of_hour(0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55) }

  include SidekiqWorkerMixin

  def self.handlers
    @handlers ||= begin
      workers_path = Rails.root.join("app/workers")
      Dir.glob(workers_path.join("commit_monitor_handlers/*.rb")).collect do |f|
        path = Pathname.new(f).relative_path_from(workers_path).to_s
        path.chomp(".rb").classify.constantize
      end
    end
  end

  def self.handlers_for(branch)
    handlers.select do |h|
      h.handled_branch_modes.include?(branch.mode) && h.enabled_for?(branch.repo)
    end
  end

  def perform
    if !first_unique_worker?
      logger.info "#{self.class} is already running, skipping"
    else
      process_repos
    end
  end

  def process_repos
    enabled_repos.includes(:branches).each { |repo| process_repo(repo) }
  end

  private

  attr_reader :repo, :branch, :new_commits, :all_commits

  def process_repo(repo)
    @repo = repo
    repo.git_fetch

    # Sort PR branches after regular branches
    sorted_branches = repo.branches.sort_by { |b| b.pull_request? ? 1 : -1 }

    sorted_branches.each do |branch|
      @branch = branch
      process_branch
    end
  end

  def process_branch
    logger.info "Processing #{repo.name}/#{branch.name}"

    @new_commits, @all_commits = detect_commits

    logger.info "Detected new commits #{new_commits}" if new_commits.any?

    save_branch_record
    process_handlers
  end

  def detect_commits
    send("detect_commits_on_#{branch.mode}_branch")
  end

  def detect_commits_on_regular_branch
    return branch.git_service.commit_ids_since(branch.last_commit), nil
  end

  def detect_commits_on_pr_branch
    all        = branch.git_service.commit_ids_since(branch.git_service.merge_base)
    comparison = compare_commits_list(branch.commits_list, all)
    return comparison[:right_only], all
  end

  def compare_commits_list(left, right)
    return {:same => left.dup, :left_only => [], :right_only => []} if left == right

    combined = left.zip_stretched(right)
    pivot    = combined.index { |c1, c2| c1 != c2 } || -1

    same = left[0...pivot]
    left_only, right_only = combined[pivot..-1].transpose.collect(&:compact)

    {:same => same, :left_only => left_only, :right_only => right_only}
  end

  def save_branch_record
    attrs = {:last_checked_on => Time.now.utc}
    attrs[:last_commit] = new_commits.last if new_commits.any?

    if all_commits != branch.commits_list
      attrs[:commits_list] = all_commits
    end

    # Update columns directly to avoid collisions with other workers.  See: https://github.com/rails/rails/issues/8328
    branch.update_columns(attrs)
  end

  def process_handlers
    self.class.handlers_for(branch).each do |handler|
      method = handler.respond_to?(:perform_batch_async) ? :perform_batch_async : :perform_async
      handler.public_send(method, branch.id, new_commits)
    end
  end
end
