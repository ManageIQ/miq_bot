module GithubService
  module Commands
    class AddReviewer < Base
      alias_as 'request_review'

      private

      def _execute(issuer:, value:)
        users = value.strip.delete('@').split(/\s*,\s*/)

        valid_users, invalid_users = users.partition { |u| valid_assignee?(u) }

        if valid_users.any?
          issue.add_reviewer(valid_users)
        end

        if invalid_users.any?
          message = "@#{issuer} Cannot add the following #{"reviewer".pluralize(invalid_users.size)} because they are not recognized: "
          message << invalid_users.join(", ")
          issue.add_comment(message)
        end
      end
    end
  end
end
