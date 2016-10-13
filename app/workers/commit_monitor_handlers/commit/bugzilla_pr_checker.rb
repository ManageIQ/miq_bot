module CommitMonitorHandlers
  module Commit
    class BugzillaPrChecker
      include Sidekiq::Worker
      sidekiq_options :queue => :miq_bot

      include BranchWorkerMixin
      include BugzillaWorkerCommon

      def self.handled_branch_modes
        [:pr]
      end

      attr_reader :commit, :message

      def perform(branch_id, commit, commit_details)
        return unless find_branch(branch_id, :pr)

        @commit  = commit
        @message = commit_details["message"]

        MiqToolsServices::Bugzilla.ids_in_git_commit_message(message).each do |bug_id|
          update_bugzilla_status(bug_id)
        end
      end

      private

      def update_bugzilla_status(bug_id)
        with_bug(bug_id) do |bug|
          add_pr_comment(bug)
          update_bug_status(bug)
          bug.save
        end
      rescue BugNotFoundError
        logger.error "Unable to find bug with id #{bug_id}."
      end

      def add_pr_comment(bug)
        if bug_has_pr_uri_comment?(bug)
          logger.info "Not commenting on bug #{bug.id} due to duplicate comment."
          return
        end

        case bug.status
        when "NEW", "ASSIGNED", "ON_DEV"
          logger.info "Adding PR comment to bug #{bug.id}."
          bug.add_comment(@branch.github_pr_uri)
        else
          logger.info "Not commenting on bug #{bug.id} due to status of #{bug.status}"
        end
      end

      def bug_has_pr_uri_comment?(bug)
        bug.comments.any? do |c|
          c.text.include?(@branch.github_pr_uri)
        end
      end

      def update_bug_status(bug)
        bug_id = bug.id
        bug_stat = bug.status
        return if bug_stat == "ON_DEV"

        case bug_stat
        when "NEW", "ASSIGNED"
          logger.info "Changing status of bug #{bug_id} to ON_DEV."
          bug.status = "ON_DEV"
        end
      end
    end
  end
end
