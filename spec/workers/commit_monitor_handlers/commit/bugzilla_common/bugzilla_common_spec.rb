require_relative "../../../../../app/workers/commit_monitor_handlers/commit/bugzilla_common/bugzilla_common"

class DummyBugzillaWorker
  include CommitMonitorHandlers::Commit::BugzillaCommon

  class << self
    attr_accessor :handled_branch_modes
  end

  def initialize(branch)
    @branch = branch
  end
end

RSpec.describe CommitMonitorHandlers::Commit::BugzillaCommon do
  after(:each) do
    DummyBugzillaWorker.handled_branch_modes = []
  end

  describe "#branch_valid?" do
    it "returns true when the branch is a pull request and the branch mode includes `:pr`" do
      DummyBugzillaWorker.handled_branch_modes = [:pr]
      dummy = DummyBugzillaWorker.new(double('branch', :pull_request? => true))

      expect(dummy.branch_valid?).to be true
    end

    it "returns true when the branch is not a pull request and the branch mode includes `:regular`" do
      DummyBugzillaWorker.handled_branch_modes = [:regular]
      dummy = DummyBugzillaWorker.new(double('branch', :pull_request? => false))

      expect(dummy.branch_valid?).to be true
    end

    it "returns false when the branch is not a pull request and the branch mode does not include `:regular`" do
      DummyBugzillaWorker.handled_branch_modes = []
      dummy = DummyBugzillaWorker.new(double('branch', :pull_request? => false))

      expect(dummy.branch_valid?).to be false
    end

    it "returns false when the branch is a pull request and the branch mode does not include `:pr`" do
      DummyBugzillaWorker.handled_branch_modes = []
      dummy = DummyBugzillaWorker.new(double('branch', :pull_request? => true))

      expect(dummy.branch_valid?).to be false
    end
  end
end
