describe CommitMonitorHandlers::CommitRange::MergeabilityChecker do
  let!(:branch)     { create(:branch) }
  let!(:pr_branch)  { create(:pr_branch, :repo => branch.repo, :merge_target => branch.name) }
  let!(:pr_branch2) { create(:pr_branch, :repo => branch.repo, :merge_target => "some-other-branch") }
  let!(:pr_branch3) { create(:pr_branch, :repo => branch.repo, :merge_target => branch.name) }

  before { stub_sidekiq_logger }

  it "runs PrMergeabilityChecker synchronously when a PR branch is updated" do
    expect(PrMergeabilityChecker).to receive(:perform_sync).once.with(pr_branch.id)

    described_class.new.perform(pr_branch.id, ["abcde123"])
  end

  it "queues up PrMergeabilityChecker for PRs targeting this branch" do
    expect(PrMergeabilityChecker).to receive(:perform_async).once.with(pr_branch.id)
    expect(PrMergeabilityChecker).to receive(:perform_async).once.with(pr_branch3.id)

    described_class.new.perform(branch.id, ["abcde123"])
  end
end
