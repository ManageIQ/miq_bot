require "spec_helper"
require "rugged"

RSpec.describe PullRequestMonitor::PrBranchRecord do
  describe ".create" do
    it "has git create a local pr branch" do
      repo = spy("Repo")
      pr = spy("pr")
      branch_name = "foo/bar"

      expect(repo).to receive(:git_fetch)

      described_class.create(repo, pr, branch_name)
    end

    it "creates a PR branch on the repo" do
      pr_branch = build(:pr_branch)
      repo = pr_branch.repo
      pr = spy("pr", :base => spy("base", :ref => "master"))
      allow(pr).to receive_message_chain(:head, :repo, :html_url).and_return("https://github.com/foo/bar")

      expected = {
        :name         => pr_branch.name,
        :commits_list => [],
        :commit_uri   => "https://github.com/foo/bar/commit/$commit",
        :pull_request => true,
        :merge_target => "master"
      }

      expect(repo).to receive(:git_fetch)
      expect(repo).to receive_message_chain(:branches, :build).with(hash_including(expected)).and_return(pr_branch)
      expect_any_instance_of(Branch).to receive_message_chain(:git_service, :merge_base).and_return(pr_branch.last_commit)
      described_class.create(repo, pr, pr_branch.name)
    end
  end

  describe ".delete" do
    it "does nothing if given no branch names" do
      repo = spy("Repo")

      expect(repo).not_to receive(:destroy_all)

      described_class.delete(repo)
    end

    it "destroys the repo's branch matching the name given" do
      repo = instance_spy("Repo")
      branch_name = "foo/bar"
      relation = spy("relation")
      allow(repo).to receive(:branches).and_return(relation)
      allow(relation).to receive(:where).with(:name => [branch_name]).and_return(relation)

      expect(relation).to receive(:destroy_all)

      described_class.delete(repo, branch_name)
    end

    it "can destroy multiple branches" do
      repo = instance_spy("Repo")
      branch_1 = "foo/bar"
      branch_2 = "baz/qux"
      relation = spy("relation")
      allow(repo).to receive(:branches).and_return(relation)
      allow(relation).to receive(:where).with(:name => [branch_1, branch_2]).and_return(relation)

      expect(relation).to receive(:destroy_all)

      described_class.delete(repo, branch_1, branch_2)
    end
  end

  describe ".prune" do
    it "prunes the stale pr branches" do
      repo = instance_spy("Repo")
      branch_name = "foo/bar"
      allow(repo).to receive(:stale_pr_branches).and_return([branch_name])
      relation = spy("relation")
      allow(repo).to receive(:branches).and_return(relation)
      allow(relation).to receive(:where).with(:name => [branch_name]).and_return(relation)

      expect(relation).to receive(:destroy_all)

      described_class.prune(repo)
    end
  end
end
