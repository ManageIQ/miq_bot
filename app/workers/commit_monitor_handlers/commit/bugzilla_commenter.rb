module CommitMonitorHandlers
  module Commit
    class BugzillaCommenter
      include Sidekiq::Worker
      sidekiq_options :queue => :miq_bot

      include BranchWorkerMixin
      include BugzillaWorkerCommon

      def self.handled_branch_modes
        [:regular]
      end

      attr_reader :commit, :message

      def perform(branch_id, commit, commit_details)
        return unless find_branch(branch_id, :regular)

        @commit  = commit
        @message = commit_details["message"]

        BugzillaService.ids_in_git_commit_message(message).each do |bug_id|
          write_to_bugzilla(bug_id)
        end
      end

      private

      def bugzilla_comment
        prefix     = "New commit detected on #{fq_repo_name}/#{branch.name}:"
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
      rescue BugNotFoundError
        logger.error "Unable to find bug with id #{bug_id}."
      end
    end
  end
end
