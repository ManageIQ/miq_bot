describe CommitMonitorHandlers::CommitRange::PathBasedLabeler do
  subject(:labeler) { described_class.new }

  let(:branch)         { create(:pr_branch) }
  let(:git_service)    { double("GitService", :diff => double("RuggedDiff", :new_files => new_files)) }
  let(:settings) do
    { "path_based_labeler" => { "enabled_repos" => { branch.repo.name => [{ "regex" => /(?:Gemfile|Gemfile\.lock|\.gemspec)\z/, "label" => "gem changes" },
                                                                          { "regex" => /db\/migrate.+\.rb\z/, "label" => "sql migration" }] } } }
  end

  before do
    stub_sidekiq_logger
    stub_settings(settings)
    labeler.branch = branch
    allow(branch).to receive(:git_service).and_return(git_service)
  end

  context "when there are Gemfile changes" do
    let(:new_files) { ["Gemfile", "some/other/file.rb"] }

    it "adds a label to the PR" do
      expect(GithubService).to receive(:add_labels_to_an_issue).with(branch.repo.name, branch.pr_number, ["gem changes"])

      labeler.perform(branch.id, nil)
    end
  end

  context "when there are gemspec changes" do
    let(:new_files) { ["some_gem.gemspec", "some/other/file.rb"] }

    it "adds a label to the PR" do
      expect(GithubService).to receive(:add_labels_to_an_issue).with(branch.repo.name, branch.pr_number, ["gem changes"])

      labeler.perform(branch.id, nil)
    end
  end

  context "when there are Gemfile changes to deep Gemfiles" do
    let(:new_files) { ["gems/pending/Gemfile", "some/other/file.rb"] }

    it "adds a label to the PR" do
      expect(GithubService).to receive(:add_labels_to_an_issue).with(branch.repo.name, branch.pr_number, ["gem changes"])

      labeler.perform(branch.id, nil)
    end
  end

  context "when there are gemspec changes to deep gemspec" do
    let(:new_files) { ["path/to/some_gem.gemspec", "some/other/file.rb"] }

    it "adds a label to the PR" do
      expect(GithubService).to receive(:add_labels_to_an_issue).with(branch.repo.name, branch.pr_number, ["gem changes"])

      labeler.perform(branch.id, nil)
    end
  end

  context "where there are no Gemfile changes" do
    let(:new_files) { ["some/other/file.rb"] }

    it "does not add a label to the PR" do
      expect(GithubService).to_not receive(:add_labels_to_an_issue)

      labeler.perform(branch.id, nil)
    end
  end

  context "when there are migrations" do
    let(:new_files) { ["db/migrate/20160706230546_some_migration.rb", "some/other/file.rb"] }

    it "adds a label to the PR" do
      expect(GithubService).to receive(:add_labels_to_an_issue).with(branch.repo.name, branch.pr_number, ["sql migration"])

      labeler.perform(branch.id, nil)
    end
  end

  context "where there are no migrations" do
    let(:new_files) { ["some/other/file.rb"] }

    it "does not add a label to the PR" do
      expect(GithubService).to_not receive(:add_labels_to_an_issue)

      labeler.perform(branch.id, nil)
    end
  end

  context "where there are changes to migration specs only" do
    let(:new_files) { ["spec/migrations/20140715200621_set_default_for_pxe_server_customization_directory_spec.rb", "some/other/file.rb"] }

    it "does not add a label to the PR" do
      expect(GithubService).to_not receive(:add_labels_to_an_issue)

      labeler.perform(branch.id, nil)
    end
  end
end
