describe PullRequestMonitorHandlers::WipLabeler do
  let(:branch)         { create(:pr_branch) }

  before do
    stub_sidekiq_logger
    stub_settings(:wip_labeler => {:enabled_repos => [branch.repo.name]})
  end

  context "when the PR title does not have [WIP]" do
    it "removes the wip label if it exists" do
      expect(NewGithubService).to receive(:remove_label).with(branch.repo.name, branch.pr_number, "wip")

      described_class.new.perform(branch.id)
    end
  end

  context "when the PR title has [WIP]" do
    it "adds the wip label if it does not exist" do
      branch.update_attributes(:pr_title => "[WIP] #{branch.pr_title}")

      expect(NewGithubService).to receive(:add_labels_to_an_issue).with(branch.repo.name, branch.pr_number, ["wip"])

      described_class.new.perform(branch.id)
    end
  end
end
