class PullRequestMonitor
  class RepoProcessor
    def self.process(repo)
      known_pr_branches = repo.pr_branch_names

      repo.with_github_service do |github|
        github.pull_requests.all.each do |pr|
          pr_branch_name = MiqToolsServices::MiniGit.pr_branch(pr.number)
          next if known_pr_branches.include?(pr_branch_name)

          PrBranchRecord.create(repo, pr, pr_branch_name)
        end
      end

      PrBranchRecord.prune(repo)
    end
  end
end
