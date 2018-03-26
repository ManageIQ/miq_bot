module GithubService
  module Commands
    class RemoveReviewer < Base
      private

      def _execute(issuer:, value:)
        user = value.strip.delete('@')

        if valid_assignee?(user)
          if requested_reviewers.include?(user)
            issue.remove_reviewer(user)
          else
            issue.add_comment("@#{issuer} '#{user}' is not in the list of requested reviewers, ignoring...")
          end
        else
          issue.add_comment("@#{issuer} '#{user}' is an invalid reviewer, ignoring...")
        end
      end

      # returns an array of user logins who were requested for a pull request review
      def requested_reviewers
        GithubService.pull_request_review_requests(fq_repo_name, number).users.map(&:login)
      end
    end
  end
end
