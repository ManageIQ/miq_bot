module CommitMonitorHandlers
  module Commit
    class BugzillaCommenter
      include Sidekiq::Worker
      sidekiq_options :queue => :miq_bot

      include BranchWorkerMixin

      def self.handled_branch_modes
        [:regular]
      end

      attr_reader :commit, :message

      def perform(branch_id, commit, commit_details)
        return unless find_branch(branch_id, :regular)

        @commit  = commit
        @message = commit_details["message"]

        BugzillaService.search_in_message(message).each do |bug|
          update_bugzilla_status(bug[:bug_id], bug[:resolution])
        end
      end

      private

      def update_bugzilla_status(bug_id, resolution)
        BugzillaService.call do |service|
          service.with_bug(bug_id) do |bug|
            break if bug.nil?

            add_pr_comment(bug)
            update_bug_status(bug) if resolution
            bug.save
          end
        end
      end

      def add_pr_comment(bug)
        logger.info "Adding comment to bug #{bug.id}."

        prefix     = "New commit detected on #{fq_repo_name}/#{branch.name}:"
        commit_uri = branch.commit_uri_to(commit)
        comment    = "#{prefix}\n#{commit_uri}\n\n#{message}"

        bug.add_comment(comment)
      end

      def update_bug_status(bug)
        case bug.status
        when "NEW", "ASSIGNED", "ON_DEV"
          logger.info "Changing status of bug #{bug.id} to POST."
          bug.status = "POST"
        else
          logger.info "Not changing status of bug #{bug.id} due to status of #{bug.status}"
        end
      end
    end
  end
end
