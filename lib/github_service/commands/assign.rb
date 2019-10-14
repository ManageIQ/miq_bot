module GithubService
  module Commands
    class Assign < Base
      private

      def _execute(issuer:, value:, **_)
        user = value.strip.delete('@')

        if valid_assignee?(user)
          issue.assign(user)
        else
          issue.add_comment("@#{issuer} '#{user}' is an invalid assignee, ignoring...")
        end
      end
    end
  end
end
