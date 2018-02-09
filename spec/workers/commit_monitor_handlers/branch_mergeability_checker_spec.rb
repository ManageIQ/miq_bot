describe CommitMonitorHandlers::CommitRange::BranchMergeabilityChecker do
  let!(:branch)     { create(:branch) }
  let!(:pr_branch)  { create(:pr_branch, :repo => branch.repo, :merge_target => branch.name) }
  let!(:pr_branch2) { create(:pr_branch, :repo => branch.repo) }

  before { stub_sidekiq_logger }

  it "queues up PrMergeabilityChecker for PRs targeting this branch" do
    expect(PrMergeabilityChecker).to receive(:perform_async).once.with(pr_branch.id)

    described_class.new.perform(branch.id, ["abcde123"])
  end
end
