module GithubService
  module Commands
    class Assign < Base
      private

      def _execute(issuer:, value:)
        user = value.strip.delete('@')

        if valid_assignee?(user)
          issue.assign(user)
        else
          issue.add_comment("@#{issuer} '#{user}' is an invalid assignee, ignoring...")
        end
      end

      def valid_assignee?(user)
        # First reload the cache if it's an invalid assignee
        GithubService.refresh_assignees(issue.fq_repo_name) unless GithubService.valid_assignee?(issue.fq_repo_name, user)

        # Then see if it's *still* invalid
        GithubService.valid_assignee?(issue.fq_repo_name, user)
      end
    end
  end
end
