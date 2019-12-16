module GithubService
  module Commands
    class Unassign < Base
      private

      def _execute(issuer:, value:)
        users = value.strip.delete('@').split(/\s*,\s*/)

        assgined_users = list_assigned_users

        valid_users, invalid_users = users.partition { |u| assgined_users.include?(u) }

        if valid_users.any?
          octokit_remove_assignees(issue.fq_repo_name, issue.number, valid_users)
        end

        if invalid_users.any?
          message = "@#{issuer} #{"User".pluralize(invalid_users.size)} '#{invalid_users.join(", ")}' #{invalid_users.size == 1 ? "is" : "are"} not in the list of assignees, ignoring..."
          issue.add_comment(message)
        end
      end

      def list_assigned_users
        GithubService.issue(issue.fq_repo_name, issue.number).assignees.map(&:login)
      end

      # FIXME: NoMethodError on `remove_assignees`
      # https://github.com/octokit/octokit.rb/blob/master/lib/octokit/client/issues.rb#L346
      def octokit_remove_assignees(repo, number, assignees, options = {})
        service = GithubService.instance_variable_get("@service")
        service.delete("repos/#{repo}/issues/#{number}/assignees", options.merge(:assignees => assignees))
      end
    end
  end
end
