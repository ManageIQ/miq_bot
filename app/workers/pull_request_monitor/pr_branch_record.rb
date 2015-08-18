class PullRequestMonitor
  class PrBranchRecord
    def self.create(git, repo, pr, branch_name)
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

    def self.delete(git, repo, *branch_names)
      return if branch_names.empty?

      repo.branches.where(:name => branch_names).destroy_all

      git.checkout("master")
      branch_names.each { |branch_name| git.destroy_branch(branch_name) }
    end

    def self.prune(git, repo)
      delete(git, repo, *repo.stale_pr_branches)
    end
  end
end
