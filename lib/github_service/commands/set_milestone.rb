module GithubService
  module Commands
    class SetMilestone < Base
      private

      def _execute(issuer:, value:, **_)
        milestone = value.strip

        if valid_milestone?(milestone)
          issue.set_milestone(milestone)
        else
          issue.add_comment("@#{issuer} Milestone #{milestone} is not recognized, ignoring...")
        end
      end

      def valid_milestone?(milestone)
        # First reload the cache if it's an invalid milestone
        GithubService.refresh_milestones(issue.fq_repo_name) unless GithubService.valid_milestone?(issue.fq_repo_name, milestone)

        # Then see if it's *still* invalid
        GithubService.valid_milestone?(issue.fq_repo_name, milestone)
      end
    end
  end
end
