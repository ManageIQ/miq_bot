describe PullRequestMonitorHandlers::MergeTargetTitler do
  let(:branch)         { create(:pr_branch) }
  let(:github_service) { stub_github_service }

  before do
    stub_sidekiq_logger
    stub_settings(:merge_target_titler => {:enabled_repos => [branch.repo.name]})
  end

  context "when the branch has a non-master merge target" do
    before do
      branch.update_attributes!(:merge_target => "darga")
    end

    it "and not already titled" do
      expect(github_service).to receive(:user).and_return("SomeUser")
      expect(github_service).to receive(:repo).and_return("some_repo")
      expect(github_service).to receive_message_chain(:pull_requests, :update).with(
        :user   => "SomeUser",
        :repo   => "some_repo",
        :number => branch.pr_number,
        :title  => "[DARGA] #{branch.pr_title}"
      )

      described_class.new.perform(branch.id)
    end

    it "and already titled" do
      branch.update_attributes!(:pr_title => "[DARGA] #{branch.pr_title}")

      expect(github_service).to_not receive(:pull_requests)

      described_class.new.perform(branch.id)
    end

    it "and already titled, but not at the start" do
      branch.update_attributes!(:pr_title => "[WIP] [DARGA] #{branch.pr_title}")

      expect(github_service).to_not receive(:pull_requests)

      described_class.new.perform(branch.id)
    end
  end

  it "when the branch has a master merge target" do
    branch.update_attributes!(:merge_target => "master")

      expect(github_service).to_not receive(:pull_requests)

    described_class.new.perform(branch.id)
  end
end
