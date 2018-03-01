module GithubService
  module Commands
    class AddReviewer < Base
      private

      def _execute(issuer:, value:)
        user = value.strip.delete('@')

        if valid_assignee?(user)
          issue.add_reviewer(user)
        else
          issue.add_comment("@#{issuer} '#{user}' is an invalid reviewer, ignoring...")
        end
      end
    end
  end
end
