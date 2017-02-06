describe PullRequestMonitorHandlers::WipLabeler do
  let(:branch)         { create(:pr_branch) }
  let(:github_service) { stub_github_service }

  before do
    stub_sidekiq_logger
    stub_settings(:wip_labeler => {:enabled_repos => [branch.repo.name]})
  end

  context "when the PR title does not have [WIP]" do
    it "removes the wip label if it exists" do
      expect(github_service).to receive(:remove_issue_labels).with(branch.pr_number, "wip")

      described_class.new.perform(branch.id)
    end
  end

  context "when the PR title has [WIP]" do
    it "adds the wip label if it does not exist" do
      branch.update_attributes(:pr_title => "[WIP] #{branch.pr_title}")

      expect(github_service).to receive(:add_issue_labels).with(branch.pr_number, "wip")

      described_class.new.perform(branch.id)
    end
  end
end
