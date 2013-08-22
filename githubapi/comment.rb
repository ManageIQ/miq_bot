require_relative 'git_hub_api'

module GitHubApi
  class Comment
    attr_accessor :issue, :updated_at, :body, :author

    def initialize(octokit_comment, issue, repo)
      @issue         = issue
      @issue_number  = issue.number
      @updated_at    = octokit_comment.updated_at
      @body          = octokit_comment.body
      @author        = octokit_comment.user.login 
      @repo          = repo
  	end
  end
end
