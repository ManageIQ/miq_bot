require "spec_helper"

RSpec.describe PullRequestMonitor::RepoProcessor do
  describe ".process" do
    it "pulls from upstream master" do
      repo = spy("CommitMonitorRepo")
      git = spy("git")
      class_spy("PrBranchRecord").as_stubbed_const

      expect(git).to receive(:checkout).with("master").ordered
      expect(git).to receive(:pull).ordered

      described_class.process(git, repo)
    end

    it "creates a pr branch record" do
      repo = spy("CommitMonitorRepo")
      git = spy("git")
      pr_branch_record = class_spy("PullRequestMonitor::PrBranchRecord").as_stubbed_const
      pull_request = double("pull request", :number => 123)
      branch_name = "foo/bar"
      allow(repo).to receive(:pull_requests).and_return([pull_request])
      allow(repo).to receive(:pr_branches).and_return([])
      allow(git).to receive(:pr_branch).with(pull_request.number).and_return(branch_name)

      expect(pr_branch_record).to receive(:create).with(git, repo, pull_request, branch_name)

      described_class.process(git, repo)
    end

    it "skips pr branch record creation if it exists" do
      repo = spy("CommitMonitorRepo")
      git = spy("git")
      pr_branch_record = class_spy("PullRequestMonitor::PrBranchRecord").as_stubbed_const
      pull_request = double("pull request", :number => 123)
      branch_name = "foo/bar"
      allow(repo).to receive(:pull_requests).and_return([pull_request])
      allow(repo).to receive(:pr_branches).and_return([double("branch", :name => branch_name)])
      allow(git).to receive(:pr_branch).with(pull_request.number).and_return(branch_name)

      expect(pr_branch_record).not_to receive(:create)

      described_class.process(git, repo)
    end

    it "prunes any stale pr branch records" do
      repo = spy("CommitMonitorRepo")
      git = spy("git")
      pr_branch_record = class_spy("PullRequestMonitor::PrBranchRecord").as_stubbed_const

      expect(pr_branch_record).to receive(:prune).with(git, repo)

      described_class.process(git, repo)
    end
  end
end
