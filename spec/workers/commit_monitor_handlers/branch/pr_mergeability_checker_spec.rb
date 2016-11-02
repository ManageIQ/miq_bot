require 'spec_helper'

describe CommitMonitorHandlers::Branch::PrMergeabilityChecker do
  before(:each) do
    stub_sidekiq_logger
  end

  let(:github_service) { stub_github_service }
  let(:pr_branch) { create(:pr_branch, :name => 'prs/1/head', :mergeable => true) }

  context 'when PR was mergeable and becomes unmergeable' do
    it 'comments on the PR' do
      git_service = instance_double('GitService::Branch', :mergeable? => false)
      allow(GitService::Branch).to receive(:new) { git_service }
      allow(github_service).to receive(:add_issue_labels)

      expect(github_service).to receive(:create_issue_comments)

      described_class.new.perform(pr_branch.id)
    end

    it "adds an 'unmergeable' label to the PR" do
      git_service = instance_double('GitService::Branch', :mergeable? => false)
      allow(GitService::Branch).to receive(:new) { git_service }
      allow(github_service).to receive(:create_issue_comments)

      expect(github_service).to receive(:add_issue_labels).with(1, 'unmergeable')

      described_class.new.perform(pr_branch.id)
    end
  end

  context 'when PR was unmergeable and becomes mergeable' do
    let(:unmergeable_pr_branch) { create(:pr_branch, :name => 'prs/1/head', :mergeable => false) }

    it "removes an 'unmergeable' label from the PR" do
      git_service = instance_double('GitService::Branch', :mergeable? => true)
      allow(GitService::Branch).to receive(:new) { git_service }
      allow(github_service).to receive(:create_issue_comments)

      allow(github_service).to receive(:user) { 'ManageIQ' }
      allow(github_service).to receive(:repo) { 'miq_bot' }
      expect(github_service).to receive_message_chain(:issues, :labels, :remove)
        .with('ManageIQ', 'miq_bot', 1, :label_name => 'unmergeable')

      described_class.new.perform(unmergeable_pr_branch.id)
    end
  end
end
