require 'spec_helper'

describe CommitMonitorHandlers::Batch::GithubPrCommenter::GemfileChecker do
  let(:commits_list)   { ["123abc", "234def"] }
  let(:diff_file_names_params) { ["master", commits_list.last] }
  let(:branch)         { create(:pr_branch, :commits_list => commits_list) }
  let(:batch_entry)    { BatchEntry.create!(:job => BatchJob.create!) }
  let(:git_service)    { stub_git_service }
  let(:github_service) { stub_github_service }

  before do
    stub_sidekiq_logger
    stub_job_completion
    stub_settings(:gemfile_checker, :pr_contacts, [])
    stub_settings(:gemfile_checker, :enabled_repos, [branch.repo.name])
    git_service
    github_service
  end

  context "when there are Gemfile changes" do
    context "adds a label to the PR" do
      before do
        expect(git_service).to receive(:diff_file_names).with(*diff_file_names_params).and_return([
          "Gemfile"
        ])

        expect(github_service).to receive(:add_issue_labels).with(branch.pr_number, "gem changes")
      end

      it "and adds a comment to the batch" do
        described_class.new.perform(batch_entry.id, branch.id, nil)

        expect(batch_entry.reload.result).to eq("Gemfile changes detected.")
      end

      it "and adds a comment to the batch with PR contacts" do
        stub_settings(:gemfile_checker, :pr_contacts, %w(@user1 @user2))

        described_class.new.perform(batch_entry.id, branch.id, nil)

        expect(batch_entry.reload.result).to eq("Gemfile changes detected. /cc @user1 @user2")
      end
    end
  end

  context "where there are no Gemfile changes" do
    before do
      expect(git_service).to receive(:diff_file_names).with(*diff_file_names_params).and_return([])
    end

    it "does not add a label to the PR" do
      expect(github_service).to_not receive(:add_issue_labels)

      described_class.new.perform(batch_entry.id, branch.id, nil)
    end

    it "does not add a comment to the batch" do
      described_class.new.perform(batch_entry.id, branch.id, nil)

      expect(batch_entry.reload.result).to be_nil
    end
  end
end
