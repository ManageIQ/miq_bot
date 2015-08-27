module BugzillaWorkerCommon
  BugNotFoundError = Class.new(StandardError)

  def product
    Settings.commit_monitor.bugzilla_product
  end

  def with_bug(bug_id)
    return unless block_given?
    MiqToolsServices::Bugzilla.call do
      output = ActiveBugzilla::Bug.find(:product => product, :id => bug_id)
      raise BugNotFoundError if output.empty?
      bug = output.first
      yield(bug)
    end
  end
end
