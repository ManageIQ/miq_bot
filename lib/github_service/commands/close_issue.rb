module GithubService
  module Commands
    class CloseIssue < Base
      restrict_to :organization

      private

      def _execute(issuer:, value:)
        if issue.pull_request? && issuer != issue.author
          issue.add_comment("@#{issuer} Only @#{issue.author} or a committer can close this pull request.")
        else
          GithubService.close_issue(issue.fq_repo_name, issue.number)
        end
      end
    end
  end
end
