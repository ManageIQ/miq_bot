module CommitMonitorHandlers
  module Commit
    module BugzillaCommon
      def product
        Settings.commit_monitor.bugzilla_product
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

      def branch_valid?
        if @branch.pull_request?
          return true if self.class.handled_branch_modes.include?(:pr)
        else
          return true if self.class.handled_branch_modes.include?(:regular)
        end
        false
      end
    end
  end
end
