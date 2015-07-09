module CommitMonitorHandlers
  module Commit
    class BugzillaPrChecker
      include Sidekiq::Worker
      include BugzillaCommon

      sidekiq_options :queue => :miq_bot

      def self.handled_branch_modes
        [:pr]
      end

      attr_reader :branch, :commit, :message

      def perform(branch_id, commit, commit_details)
        logger.info("Performing bugzilla PR check on branch #{branch_id}")
        @branch  = CommitMonitorBranch.where(:id => branch_id).first
        @commit  = commit
        @message = commit_details["message"]

        return unless branch_valid?

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
      end

      def add_pr_comment(bug)
        if bug_has_pr_uri_comment?(bug)
          logger.info "Not commenting on bug #{bug.id} due to duplicate comment."
        else
          logger.info "Adding PR comment to bug #{bug.id}."
          bug.add_comment(@branch.github_pr_uri)
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
        if bug_stat == "NEW" || bug_stat == "ASSIGNED"
          logger.info "Changing status of bug #{bug_id} to ON_DEV."
          bug.status = "ON_DEV"
        else
          logger.warn "Not changing status of bug #{bug_id} from #{bug_stat}."
          if bug_stat != "ON_DEV"
            bug.add_comment("Detected commit referencing this ticket while ticket status is #{bug_stat}.")
            bug.flags["needinfo"] = "?"
          end
        end
      end
    end
  end
end
