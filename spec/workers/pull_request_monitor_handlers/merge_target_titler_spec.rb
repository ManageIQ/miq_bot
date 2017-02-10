describe PullRequestMonitorHandlers::MergeTargetTitler do
  let(:branch) { create(:pr_branch) }

  before do
    stub_sidekiq_logger
    stub_settings(:merge_target_titler => {:enabled_repos => [branch.repo.name]})
  end

  context "when the branch has a non-master merge target" do
    before do
      branch.update_attributes!(:merge_target => "darga")
    end

    it "and not already titled" do
      expect(GithubService).to receive(:update_pull_request)
        .with(branch.repo.name, branch.pr_number, a_hash_including(:title => "[DARGA] #{branch.pr_title}"))
      described_class.new.perform(branch.id)
    end

    it "and already titled" do
      branch.update_attributes!(:pr_title => "[DARGA] #{branch.pr_title}")

      expect(GithubService).to_not receive(:pull_requests)

      described_class.new.perform(branch.id)
    end

    it "and already titled, but not at the start" do
      branch.update_attributes!(:pr_title => "[WIP] [DARGA] #{branch.pr_title}")

      expect(GithubService).to_not receive(:pull_requests)

      described_class.new.perform(branch.id)
    end
  end

  it "when the branch has a master merge target" do
    branch.update_attributes!(:merge_target => "master")

    expect(GithubService).to_not receive(:pull_requests)

    described_class.new.perform(branch.id)
  end
end
