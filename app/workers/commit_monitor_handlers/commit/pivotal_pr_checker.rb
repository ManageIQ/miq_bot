module CommitMonitorHandlers
  module Commit
    class PivotalPrChecker
      include Sidekiq::Worker
      sidekiq_options :queue => :miq_bot

      include BranchWorkerMixin

      def self.handled_branch_modes
        [:pr]
      end

      attr_reader :commit, :message

      def perform(branch_id, commit, commit_details)
        return unless find_branch(branch_id, :pr)
        return unless verify_branch_enabled

        @commit  = commit
        @message = commit_details["message"]

        PivotalService.ids_in_git_commit_message(message).each do |story_id|
          update_pivotal_story(story_id)
        end
      end

      private

      def update_pivotal_story(story_id)
        PivotalService.call do |client|
          story = client.story(story_id)
          story.create_comment(:text => branch.github_pr_uri) unless already_linked?(story)
        end
      end

      def already_linked?(story)
        github_pr_uri?(story.description) || story.comments.any? { |comment| github_pr_uri?(comment.text) }
      end

      def github_pr_uri?(text)
        text.include?(branch.github_pr_uri)
      end
    end
  end
end
