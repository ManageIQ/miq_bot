describe PrMergeabilityChecker do
  before(:each) do
    stub_sidekiq_logger
  end

  let(:pr_branch) { create(:pr_branch, :name => 'prs/1/head', :mergeable => true) }
  let(:repo_name) { pr_branch.repo.name }

  context 'when PR was mergeable and becomes unmergeable' do
    it 'comments on the PR' do
      git_service = instance_double('GitService::Branch', :mergeable? => false)
      allow(GitService::Branch).to receive(:new) { git_service }
      allow(GithubService).to receive(:add_labels_to_an_issue)

      expect(GithubService).to receive(:add_comment)
        .with(repo_name, 1, a_string_including("not mergeable"))

      described_class.new.perform(pr_branch.id)
    end

    it "adds an 'unmergeable' label to the PR" do
      git_service = instance_double('GitService::Branch', :mergeable? => false)
      allow(GitService::Branch).to receive(:new) { git_service }
      allow(GithubService).to receive(:add_comment)

      expect(GithubService).to receive(:add_labels_to_an_issue)
        .with(repo_name, 1, ['unmergeable'])

      described_class.new.perform(pr_branch.id)
    end
  end

  context 'when PR was unmergeable and becomes mergeable' do
    let(:username) { "tux" }
    let(:user) { double("User", :id => 42, :login => username) }
    let(:body) { "<pr-mergeability-checker />This pull request is not mergeable.  Please rebase and repush." }
    let(:comment) { double("Comment", :id => 9, :body => body, :user => user) }
    let(:pr_branch) { create(:pr_branch, :name => 'prs/1/head', :mergeable => false) }

    before do
      stub_settings(Hash(:github_credentials => {:username => username}))
    end

    it "removes an 'unmergeable' label and comments from the PR" do
      git_service = instance_double('GitService::Branch', :mergeable? => true)

      allow(GitService::Branch).to receive(:new) { git_service }
      allow(GithubService).to receive(:add_comment)

      expect(GithubService).to receive(:remove_label).with(repo_name, 1, 'unmergeable')
      expect(GithubService).to receive(:issue_comments).with(repo_name, 1).and_return([comment, comment])
      expect(GithubService).to receive(:delete_comments).with(repo_name, [9, 9]).once

      described_class.new.perform(pr_branch.id)
    end
  end
end
