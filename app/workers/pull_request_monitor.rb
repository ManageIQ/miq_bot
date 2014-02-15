class PullRequestMonitor
  include Sidekiq::Worker

  def perform
    process_repos
  end

  private

  attr_reader :repo, :git, :github, :pr

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

    original_pr_branches = pr_branches
    current_pr_branches  = process_prs
    delete_pr_branches(original_pr_branches - current_pr_branches)
  end

  def process_prs
    GithubService.call(:repo => repo) do |github|
      @github = github
      github.pull_requests.all.collect do |pr|
        @pr = pr
        process_pr
      end
    end
  end

  def process_pr
    branch_name = git.pr_branch(pr.number)

    unless pr_branches.include?(branch_name)
      git.create_pr_branch(branch_name)
      create_pr_branch_record(branch_name)
    end

    branch_name
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

  def pr_branches
    repo.branches.select(&:pull_request?).collect(&:name)
  end

  def delete_pr_branches(branch_names)
    return if branch_names.empty?

    repo.branches.where(:name => branch_names).destroy_all

    git.checkout("master")
    branch_names.each { |branch_name| git.destroy_branch(branch_name) }
  end
end
