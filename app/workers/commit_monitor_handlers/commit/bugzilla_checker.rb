module CommitMonitorHandlers
  module Commit
    class BugzillaChecker
      include Sidekiq::Worker
      sidekiq_options :queue => :miq_bot

      def self.handled_branch_modes
        [:regular, :pr]
      end

      attr_reader :branch, :commit, :message

      def perform(branch_id, commit, commit_details)
        logger.info("Performing bugzilla check on branch #{branch_id}")
        @branch  = CommitMonitorBranch.where(:id => branch_id).first
        @commit  = commit
        @message = commit_details["message"]

        if @branch.nil?
          logger.info("Branch #{branch_id} no longer exists.  Skipping.")
          return
        end

        process_commit
      end

      private

      def product
        Settings.commit_monitor.bugzilla_product
      end

      def bug_has_pr_uri_comment?(bug)
        bug.comments.any? do |c|
          c.text.include?(@branch.github_pr_uri)
        end
      end

      def bugzilla_comment
        prefix     = "New commit detected on #{branch.repo.name}/#{branch.name}:"
        commit_uri = branch.commit_uri_to(commit)
        comment    = "#{prefix}\n#{commit_uri}\n\n#{message}"
        comment
      end

      def with_bug(bug_id)
        return unless block_given?
        MiqToolsServices::Bugzilla.call do
          output = ActiveBugzilla::Bug.find(:product => product, :id => bug_id)
          if output.empty?
            logger.error "Unable to write for bug id #{bug_id}: Not a '#{product}' bug."
          else
            bug = output.first
            yield(bug)
          end
        end
      rescue => err
        logger.error "Unable to write for bug id #{bug_id}: #{err}"
      end

      def process_commit
        MiqToolsServices::Bugzilla.ids_in_git_commit_message(message).each do |bug_id|
          if @branch.pull_request?
            update_bugzilla_status(bug_id)
          else
            write_to_bugzilla(bug_id)
          end
        end
      end

      def write_to_bugzilla(bug_id)
        with_bug(bug_id) do |bug|
          logger.info "Writing to bugzilla for bug id #{bug_id}"
          bug.add_comment(bugzilla_comment)
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

      def update_bugzilla_status(bug_id)
        with_bug(bug_id) do |bug|
          add_pr_comment(bug)
          update_bug_status(bug)
          bug.save
        end
      end
    end
  end
end
