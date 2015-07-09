module CommitMonitorHandlers
  module Commit
    class BugzillaCommenter
      include Sidekiq::Worker
      include BugzillaCommon

      sidekiq_options :queue => :miq_bot

      def self.handled_branch_modes
        [:regular]
      end

      attr_reader :branch, :commit, :message

      def perform(branch_id, commit, commit_details)
        logger.info("Performing bugzilla check on branch #{branch_id}")
        @branch  = CommitMonitorBranch.where(:id => branch_id).first
        @commit  = commit
        @message = commit_details["message"]

        return unless branch_valid?

        MiqToolsServices::Bugzilla.ids_in_git_commit_message(message).each do |bug_id|
          write_to_bugzilla(bug_id)
        end
      end

      private

      def bugzilla_comment
        prefix     = "New commit detected on #{branch.repo.name}/#{branch.name}:"
        commit_uri = branch.commit_uri_to(commit)
        comment    = "#{prefix}\n#{commit_uri}\n\n#{message}"
        comment
      end

      def write_to_bugzilla(bug_id)
        with_bug(bug_id) do |bug|
          logger.info "Writing to bugzilla for bug id #{bug_id}"
          bug.add_comment(bugzilla_comment)
          bug.save
        end
      end
    end
  end
end
