class PullRequestMonitor
  class RepoProcessor
    def self.process(git, repo)
      git.checkout("master")
      git.pull

      repo.pull_requests.each do |pr|
        branch_name = git.pr_branch(pr.number)
        next if repo.pr_branches.collect(&:name).include?(branch_name)
        PrBranchRecord.create(git, repo, pr, branch_name)
      end

      PrBranchRecord.prune(git, repo)
    end
  end
end
