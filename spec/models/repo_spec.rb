require 'rails_helper'

describe Repo do
  let(:repo) { build(:repo) }

  describe "#name_parts" do
    it "without an upstream user" do
      repo.name = "foo"
      expect(repo.name_parts).to eq([nil, "foo"])
    end

    it "with an upstream user" do
      repo.name = "foo/bar"
      expect(repo.name_parts).to eq(["foo", "bar"])
    end

    it "with extra parts" do
      repo.name = "foo/bar/baz"
      expect(repo.name_parts).to eq(["foo", "bar/baz"])
    end
  end

  describe "#upstream_user" do
    it "without an upstream user" do
      repo.name = "foo"
      expect(repo.upstream_user).to be_nil
    end

    it "with an upstream user" do
      repo.name = "foo/bar"
      expect(repo.upstream_user).to eq("foo")
    end
  end

  describe "#project" do
    it "without an upstream user" do
      repo.name = "foo"
      expect(repo.project).to eq("foo")
    end

    it "with an upstream user" do
      repo.name = "foo/bar"
      expect(repo.project).to eq("bar")
    end
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
    stale_branch = create(:branch, :name => "pr/1", :repo => repo, :pull_request => true)

    github = stub_github_service
    stub_github_prs(github, [double("Github PR", :number => 2)])

    allow(MiqToolsServices::MiniGit).to receive(:pr_branch).with(2)

    expect(repo.stale_pr_branches).to eq([stale_branch.name])
  end
end
