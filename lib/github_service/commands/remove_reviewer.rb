module GithubService
  module Commands
    class RemoveReviewer < Base
      private

      def _execute(issuer:, value:)
        user = value.strip.delete('@')

        if valid_assignee?(user)
          if requested_reviewers.include?(user)
            # FIXME: waiting for merge of https://github.com/octokit/octokit.rb/pull/990
            begin
              issue.remove_reviewer(user)
            rescue NoMethodError
              # TODO: Remove this exception handling after dependence merge.
              octokit_request_pull_request_review(issue.fq_repo_name, issue.number, "reviewers" => [user])
            end
          else
            issue.add_comment("@#{issuer} '#{user}' is not in the list of requested reviewers, ignoring...")
          end
        else
          issue.add_comment("@#{issuer} '#{user}' is an invalid reviewer, ignoring...")
        end
      end

      # returns an array of user logins who were requested for a pull request review
      def requested_reviewers
        GithubService.pull_request_review_requests(issue.fq_repo_name, issue.number).users.map(&:login)
      end

      # TODO: Remove this.
      def octokit_request_pull_request_review(repo, id, reviewers, options = {})
        service = GithubService.instance_variable_get("@service")
        options = options.merge(:reviewers => reviewers.values.flatten)
        service.delete("repos/#{repo}/pulls/#{id}/requested_reviewers", options)
      end
    end
  end
end
