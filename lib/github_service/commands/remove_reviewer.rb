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
              issue.add_comment("@#{issuer} `remove_reviewer [@]user` is currently not working, waiting for merge"\
                                " of [dependent pull request](https://github.com/octokit/octokit.rb/pull/990)!")
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
    end
  end
end
