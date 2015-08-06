class PullRequestMonitor
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
