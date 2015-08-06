class PullRequestMonitor
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
end
