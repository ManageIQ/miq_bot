require 'spec_helper'

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
    let(:pr_branch) { create(:pr_branch, :name => 'prs/1/head', :mergeable => false) }

    it "removes an 'unmergeable' label from the PR" do
      git_service = instance_double('GitService::Branch', :mergeable? => true)
      allow(GitService::Branch).to receive(:new) { git_service }
      allow(GithubService).to receive(:add_comment)

      expect(GithubService).to receive(:remove_label)
        .with(repo_name, 1, 'unmergeable')

      described_class.new.perform(pr_branch.id)
    end
  end
end
