require "spec_helper"

RSpec.describe PullRequestMonitor::PrBranchRecord do
  describe ".create" do
    it "has git create a local pr branch" do
      repo = instance_spy("CommitMonitorRepo")
      pr = spy("pr")
      branch_name = "foo/bar"
      git = spy("git")
      allow(repo).to receive(:with_git_service).and_yield(git)

      expect(git).to receive(:create_pr_branch).with(branch_name).once

      described_class.create(repo, pr, branch_name)
    end

    it "creates a PR branch on the repo" do
      repo = instance_spy("CommitMonitorRepo")
      pr = spy("pr")
      branch_name = "foo/bar"
      last_commit = "123456"
      git = spy("git")
      allow(repo).to receive(:with_git_service).and_yield(git)
      allow(git).to receive(:merge_base).with(branch_name, "master").and_return(last_commit)
      allow(pr).to receive_message_chain(:head, :repo, :html_url)
        .and_return("https://github.com/foo/bar")

      expected = {
        :name         => branch_name,
        :last_commit  => last_commit,
        :commits_list => [],
        :commit_uri   => "https://github.com/foo/bar/commit/$commit",
        :pull_request => true
      }
      expect(repo).to receive_message_chain(:branches, :create!).with hash_including(expected)
      described_class.create(repo, pr, branch_name)
    end
  end

  describe ".delete" do
    it "does nothing if given no branch names" do
      repo = instance_spy("CommitMonitorRepo")
      git = spy("git")
      allow(repo).to receive(:with_git_service).and_yield(git)

      expect(repo).not_to receive(:destroy_all)
      expect(git).not_to receive(:destroy_branch)

      described_class.delete(repo)
    end

    it "destroys the repo's branch matching the name given" do
      repo = instance_spy("CommitMonitorRepo")
      branch_name = "foo/bar"
      relation = spy("relation")
      allow(repo).to receive(:branches).and_return(relation)
      allow(relation).to receive(:where).with(:name => [branch_name]).and_return(relation)

      expect(relation).to receive(:destroy_all)

      described_class.delete(repo, branch_name)
    end

    it "can destroy multiple branches" do
      repo = instance_spy("CommitMonitorRepo")
      branch_1 = "foo/bar"
      branch_2 = "baz/qux"
      relation = spy("relation")
      allow(repo).to receive(:branches).and_return(relation)
      allow(relation).to receive(:where).with(:name => [branch_1, branch_2]).and_return(relation)

      expect(relation).to receive(:destroy_all)

      described_class.delete(repo, branch_1, branch_2)
    end

    it "has git delete the local branches" do
      repo = instance_spy("CommitMonitorRepo")
      git = spy("git")
      allow(repo).to receive(:with_git_service).and_yield(git)
      branch_name = "foo/bar"

      expect(git).to receive(:destroy_branch).with(branch_name)

      described_class.delete(repo, branch_name)
    end
  end

  describe ".prune" do
    it "prunes the stale pr branches" do
      repo = instance_spy("CommitMonitorRepo")
      git = spy("git")
      branch_name = "foo/bar"
      allow(repo).to receive(:with_git_service).and_yield(git)
      allow(repo).to receive(:stale_pr_branches).and_return([branch_name])
      relation = spy("relation")
      allow(repo).to receive(:branches).and_return(relation)
      allow(relation).to receive(:where).with(:name => [branch_name]).and_return(relation)

      expect(relation).to receive(:destroy_all)
      expect(git).to receive(:destroy_branch).with(branch_name)

      described_class.prune(repo)
    end
  end
end
