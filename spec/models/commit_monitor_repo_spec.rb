require 'spec_helper'

describe CommitMonitorRepo do
  let(:repo) do
    CommitMonitorRepo.new(
      :upstream_user => "some_user",
      :name          => "some_repo"
    )
  end

  it "#fq_name" do
    expect(repo.fq_name).to eq "some_user/some_repo"
  end

  context ".path=" do
    let(:home) { File.expand_path("~") }

    it "with expanded path" do
      repo.path = "~/path"
      expect(repo.path).to eq File.join(home, "path")
    end

    it "with unexpanded path" do
      repo.path = "/Users/me/path"
      expect(repo.path).to eq "/Users/me/path"
    end
  end

  describe "#pr_branches" do
    it "returns the repo's branches that are pull requests" do
      repo = create(:repo)
      pr_branch = create(:branch, :repo => repo, :pull_request => true)
      non_pr_branch = create(:branch, :repo => repo, :pull_request => false)
      expect(repo.pr_branches).to contain_exactly(pr_branch)
    end
  end

  describe "#current_pr_branch_names" do
    it "returns the repo's current pr branch names" do
      repo = create(:repo)
      git = double("git")
      allow(MiqToolsServices::MiniGit).to receive(:call).with(repo.path).and_yield(git)
      allow(git).to receive(:pr_branch).with(123).and_return "feature/foo"
      pull_request = double("pull request", :number => 123)
      relation = double("relation", :all => [pull_request])
      github = double("github", :pull_requests => relation)
      allow(MiqToolsServices::Github)
        .to receive(:call).with(:repo => repo.name, :user => repo.upstream_user).and_yield(github)

      expect(repo.current_pr_branch_names).to contain_exactly "feature/foo"
    end
  end

  describe "#pull_requests" do
    it "returns the repo's pull requests" do
      repo = create(:repo)
      pull_requests = double("pull requests")
      relation = double("relation", :all => pull_requests)
      github = double("github", :pull_requests => relation)
      allow(MiqToolsServices::Github)
        .to receive(:call).with(:repo => repo.name, :user => repo.upstream_user).and_yield(github)

      expect(repo.pull_requests).to eq pull_requests
    end
  end

  describe "#stale_pr_branches" do
    it "returns the repo's stale pr branches" do
      repo = create(:repo)
      stale_branch = create(:branch, :name => "stale branch", :repo => repo, :pull_request => true)
      git = double("git")
      allow(git).to receive(:pr_branch).with(123).and_return "current branch"
      allow(MiqToolsServices::MiniGit).to receive(:call).with(repo.path).and_yield(git)
      pull_request = double("pull request", :number => 123)
      relation = double("relation", :all => [pull_request])
      github = double("github", :pull_requests => relation)
      allow(MiqToolsServices::Github)
        .to receive(:call).with(:repo => repo.name, :user => repo.upstream_user).and_yield(github)

      expect(repo.stale_pr_branches).to contain_exactly stale_branch.name
    end
  end
end
