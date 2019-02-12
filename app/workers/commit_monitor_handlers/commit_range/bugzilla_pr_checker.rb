module CommitMonitorHandlers
  module CommitRange
    class BugzillaPrChecker
      include Sidekiq::Worker
      sidekiq_options :queue => :miq_bot

      include BranchWorkerMixin

      def self.handled_branch_modes
        [:pr]
      end

      def perform(branch_id, new_commits)
        return unless find_branch(branch_id, :pr)

        bug_ids = new_commits.flat_map do |commit|
          message = repo.git_service.commit(commit).full_message
          BugzillaService.ids_in_git_commit_message(message)
        end

        bug_ids.uniq.each do |bug_id|
          update_bugzilla_status(bug_id)
        end
      end

      private

      def update_bugzilla_status(bug_id)
        BugzillaService.call do |service|
          service.with_bug(bug_id) do |bug|
            break if bug.nil?

            add_pr_comment(bug)
            update_bug_status(bug)
          end
        end
      end

      def add_pr_comment(bug)
        if bug_has_pr_uri_comment?(bug)
          logger.info "Not commenting on bug #{bug.id} due to duplicate comment."
          return
        end

        case bug.status
        when "NEW", "ASSIGNED", "ON_DEV"
          logger.info "Adding comment to bug #{bug.id}."
          bug.add_comment(@branch.github_pr_uri)
        else
          logger.info "Not commenting on bug #{bug.id} due to status of #{bug.status}"
        end
      end

      def bug_has_pr_uri_comment?(bug)
        bug.comments.any? do |comment_text|
          comment_text.include?(@branch.github_pr_uri)
        end
      end

      def update_bug_status(bug)
        case bug.status
        when "NEW", "ASSIGNED"
          logger.info "Changing status of bug #{bug.id} to ON_DEV."
          bug.status = "ON_DEV"
          bug.save
        else
          logger.info "Not changing status of bug #{bug.id} due to status of #{bug.status}"
        end
      end
    end
  end
end
