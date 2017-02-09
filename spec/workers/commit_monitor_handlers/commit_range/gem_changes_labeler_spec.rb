describe CommitMonitorHandlers::CommitRange::GemChangesLabeler do
  let(:branch)         { create(:pr_branch) }
  let(:git_service)    { double("GitService", :diff => double("RuggedDiff", :new_files => new_files)) }

  before do
    stub_sidekiq_logger
    stub_settings(:gem_changes_labeler => {:enabled_repos => [branch.repo.name]})
    expect_any_instance_of(Branch).to receive(:git_service).and_return(git_service)
  end

  context "when there are Gemfile changes" do
    let(:new_files) { ["Gemfile", "some/other/file.rb"] }

    it "adds a label to the PR" do
      expect(NewGithubService).to receive(:add_labels_to_an_issue).with(branch.repo.name, branch.pr_number, ["gem changes"])

      described_class.new.perform(branch.id, nil)
    end
  end

  context "when there are gemspec changes" do
    let(:new_files) { ["some_gem.gemspec", "some/other/file.rb"] }

    it "adds a label to the PR" do
      expect(NewGithubService).to receive(:add_labels_to_an_issue).with(branch.repo.name, branch.pr_number, ["gem changes"])

      described_class.new.perform(branch.id, nil)
    end
  end

  context "when there are Gemfile changes to deep Gemfiles" do
    let(:new_files) { ["gems/pending/Gemfile", "some/other/file.rb"] }

    it "adds a label to the PR" do
      expect(NewGithubService).to receive(:add_labels_to_an_issue).with(branch.repo.name, branch.pr_number, ["gem changes"])

      described_class.new.perform(branch.id, nil)
    end
  end

  context "when there are gemspec changes to deep gemspec" do
    let(:new_files) { ["path/to/some_gem.gemspec", "some/other/file.rb"] }

    it "adds a label to the PR" do
      expect(NewGithubService).to receive(:add_labels_to_an_issue).with(branch.repo.name, branch.pr_number, ["gem changes"])

      described_class.new.perform(branch.id, nil)
    end
  end

  context "where there are no Gemfile changes" do
    let(:new_files) { ["some/other/file.rb"] }

    it "does not add a label to the PR" do
      expect(NewGithubService).to_not receive(:add_labels_to_an_issue)

      described_class.new.perform(branch.id, nil)
    end
  end
end
