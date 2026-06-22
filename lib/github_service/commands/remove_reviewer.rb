module GithubService
  module Commands
    class RemoveReviewer < Base
      alias_as 'rm_reviewer'

      private

      def _execute(issuer:, value:)
        user = value.strip.delete('@')

        if valid_assignee?(user)
          if issue.requested_reviewers.include?(user)
            issue.remove_reviewer(user)
          else
            issue.add_comment("@#{issuer} '#{user}' is not in the list of requested reviewers, ignoring...")
          end
        else
          issue.add_comment("@#{issuer} '#{user}' is an invalid reviewer, ignoring...")
        end
      end
    end
  end
end
