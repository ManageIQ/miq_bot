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

  def process_repos
    CommitMonitorRepo.includes(:branches).each do |repo|
      next unless repo.upstream_user
      RepoProcessor.process(repo)
    end
  end

  class RepoProcessor
    def self.process(repo)
      repo.with_git_service do |git|
        git.checkout("master")
        git.pull

        repo.pull_requests.each do |pr|
          branch_name = git.pr_branch(pr.number)
          next if repo.pr_branches.collect(&:name).include?(branch_name)
          PrBranchRecord.create(repo, pr, branch_name)
        end

        PrBranchRecord.prune(repo)
      end
    end
  end

  class PrBranchRecord
    def self.create(repo, pr, branch_name)
      repo.with_git_service do |git|
        git.create_pr_branch(branch_name)
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
    end

    def self.delete(repo, *branch_names)
      return if branch_names.empty?

      repo.branches.where(:name => branch_names).destroy_all

      repo.with_git_service do |git|
        git.checkout("master")
        branch_names.each { |branch_name| git.destroy_branch(branch_name) }
      end
    end

    def self.prune(repo)
      delete(repo, repo.stale_pr_branches)
    end
  end
end
