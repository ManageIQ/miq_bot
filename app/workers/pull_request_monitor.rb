class PullRequestMonitor
  include Sidekiq::Worker
  include Sidetiq::Schedulable
  include MiqToolsServices::SidekiqWorkerMixin
  sidekiq_options :queue => :miq_bot, :retry => false

  recurrence { hourly.minute_of_hour(0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55) }

  def perform
    if !first_unique_worker?
      logger.info "#{self.class} is already running, skipping"
    else
      process_repos
    end
  end

  private

  attr_reader :repo, :git, :pr

  def process_repos
    CommitMonitorRepo.includes(:branches).each do |repo|
      next unless repo.upstream_user

      @repo = repo
      repo.with_git_service do |git|
        @git = git
        process_repo
      end
    end
  end

  def process_repo
    git.checkout("master")
    git.pull

    process_prs
    delete_pr_branches(repo.stale_pr_branches)
  end

  def process_prs
    repo.pull_requests.each do |pr|
      @pr = pr
      process_pr
    end
  end

  def process_pr
    branch_name = git.pr_branch(pr.number)
    return if repo.pr_branches.collect(&:name).include?(branch_name)
    git.create_pr_branch(branch_name)
    create_pr_branch_record(branch_name)
  end

  def create_pr_branch_record(branch_name)
    commit_uri  = File.join(pr.head.repo.html_url, "commit", "$commit")
    last_commit = git.merge_base(branch_name, "master")
    repo.branches.create!(
      :name         => branch_name,
      :last_commit  => last_commit,
      :commits_list => [],
      :commit_uri   => commit_uri,
      :pull_request => true
    )
  end

  def delete_pr_branches(branch_names)
    return if branch_names.empty?

    repo.branches.where(:name => branch_names).destroy_all

    git.checkout("master")
    branch_names.each { |branch_name| git.destroy_branch(branch_name) }
  end
end
