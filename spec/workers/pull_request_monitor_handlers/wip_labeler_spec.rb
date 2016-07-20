describe PullRequestMonitorHandlers::WipLabeler do
  let(:branch)         { create(:pr_branch) }
  let(:github_service) { stub_github_service }

  before do
    stub_sidekiq_logger
    stub_settings(:wip_labeler => {:enabled_repos => [branch.repo.name]})
  end

  it "when the PR title does not have [WIP]" do
    expect(github_service).to_not receive(:add_issue_labels)

    described_class.new.perform(branch.id)
  end

  it "when the PR title has [WIP]" do
    branch.update_attributes(:pr_title => "[WIP] #{branch.pr_title}")

    expect(github_service).to receive(:add_issue_labels).with(branch.pr_number, "wip")

    described_class.new.perform(branch.id)
  end
end
