require 'spec_helper'

describe Repo do
  let(:repo) { build(:repo) }

  it "#fq_name" do
    expect(repo.fq_name).to eq "#{repo.upstream_user}/#{repo.name}"
  end

  context "#path / #path=" do
    let(:home) { File.expand_path("~") }

    it "with expandable path" do
      repo.path = "~/path"
      expect(repo.path).to eq File.expand_path("~/path")
    end

    it "with absolute path" do
      repo.path = "/Users/me/path"
      expect(repo.path).to eq "/Users/me/path"
    end
  end

  it "#branch_names" do
    repo.save!
    branch1 = create(:branch, :repo => repo, :pull_request => true)
    branch2 = create(:branch, :repo => repo, :pull_request => false)

    expect(repo.branch_names).to match_array([branch1.name, branch2.name])
  end

  it "#pr_branches" do
    repo.save!
    pr_branch1     = create(:branch, :repo => repo, :pull_request => true)
    pr_branch2     = create(:branch, :repo => repo, :pull_request => true)
    _non_pr_branch = create(:branch, :repo => repo, :pull_request => false)

    expect(repo.pr_branches).to match_array([pr_branch1, pr_branch2])
  end

  it "#pr_branch_names" do
    repo.save!
    pr_branch1     = create(:branch, :repo => repo, :pull_request => true)
    pr_branch2     = create(:branch, :repo => repo, :pull_request => true)
    _non_pr_branch = create(:branch, :repo => repo, :pull_request => false)

    expect(repo.pr_branch_names).to match_array([pr_branch1.name, pr_branch2.name])
  end

  it "#stale_pr_branches" do
    repo.save!
    stale_branch = create(:branch, :name => "stale branch", :repo => repo, :pull_request => true)
    allow(MiqToolsServices::MiniGit).to receive(:pr_branch).with(123).and_return "current branch"
    pull_request = double("pull request", :number => 123)
    relation = double("relation", :all => [pull_request])
    github = double("github", :pull_requests => relation)
    allow(MiqToolsServices::Github)
      .to receive(:call).with(:repo => repo.name, :user => repo.upstream_user).and_yield(github)

    expect(repo.stale_pr_branches).to contain_exactly stale_branch.name
  end
end
