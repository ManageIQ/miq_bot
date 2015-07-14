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

      def handled_mode?(mode)
        self.class.handled_branch_modes.include?(mode)
      end

      def branch_valid?
        if @branch.pull_request?
          handled_mode?(:pr)
        else
          handled_mode?(:regular)
        end
      end
    end
  end
end
