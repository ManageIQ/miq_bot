describe CommitMonitorHandlers::CommitRange::GraphicsLabeler do
  let(:branch)         { create(:pr_branch) }
  let(:git_service)    { double("GitService", :diff => double("RuggedDiff", :new_files => new_files)) }

  before do
    stub_sidekiq_logger
    stub_settings(:graphics_labeler => {:enabled_repos => [branch.repo.name]})
    expect_any_instance_of(Branch).to receive(:git_service).and_return(git_service)
  end

  context "when there are image changes" do
    let(:new_files) { ["image.png", "some/other/file.rb"] }

    it "adds a label to the PR" do
      expect(GithubService).to receive(:add_labels_to_an_issue).with(branch.repo.name, branch.pr_number, ["graphics"])

      described_class.new.perform(branch.id, nil)
    end
  end

  context "where there are no image changes" do
    let(:new_files) { ["some/other/file.rb"] }

    it "does not add a label to the PR" do
      expect(GithubService).to_not receive(:add_labels_to_an_issue)

      described_class.new.perform(branch.id, nil)
    end
  end
end
