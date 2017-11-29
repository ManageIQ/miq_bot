require 'spec_helper'

describe Repo do
  let(:repo) { build(:repo) }

  it ".create_from_github!" do
    expected_repo_dir = described_class::BASE_PATH.join("foo/bar")

    expect(MinigitService).to receive(:clone)
    expect(MinigitService).to receive(:call).with(expected_repo_dir).and_return(nil)        # ensure_prs_refs

    git_service_branch = double(:exists? => true)
    expect(GitService::Branch).to receive(:new).twice.and_return(git_service_branch)
    expect(git_service_branch).to receive(:merge_base).with("master").and_return("0123abcd")

    described_class.create_from_github!("foo/bar", "https://github.com/foo/bar.git")

    repo = described_class.first
    expect(repo.name).to eq("foo/bar")
    expect(repo.branches.size).to eq(1)

    branch = repo.branches.first
    expect(branch.name).to        eq("master")
    expect(branch.commit_uri).to  eq("https://github.com/foo/bar/commit/$commit")
    expect(branch.last_commit).to eq("0123abcd")
  end

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

  describe "#can_have_prs?" do
    it "without an upstream user" do
      repo.name = "foo"
      expect(repo.can_have_prs?).to be_falsey
    end

    it "with an upstream user" do
      repo.name = "foo/bar"
      expect(repo.can_have_prs?).to be_truthy
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

  it "#path" do
    expected = Rails.root.join("repos", repo.name)
    expect(repo.path).to eq(expected)
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

  describe "#synchronize_pr_branches" do
    it "does not allow calling on a repo that can't have PRs (because of no upstream_user)" do
      repo.update_attributes(:name => "foo")

      expect { repo.synchronize_pr_branches([]) }.to raise_error(RuntimeError)
    end

    it "creates/updates/deletes PR branches" do
      pr_branch_to_keep   = create(:pr_branch, :repo => repo)
      pr_branch_to_change = create(:pr_branch, :repo => repo)
      pr_branch_to_delete = create(:pr_branch, :repo => repo)
      pr_number_to_create = pr_branch_to_delete.pr_number + 1

      git_service = double("Git service", :merge_base => "123abc")
      expect(repo).to receive(:git_fetch)
      allow_any_instance_of(Branch).to receive(:git_service).and_return(git_service)

      results = repo.synchronize_pr_branches([
        {
          :number       => pr_branch_to_keep.pr_number,
          :html_url     => "https://example.com/#{repo.name}",
          :merge_target => pr_branch_to_keep.merge_target,
          :pr_title     => pr_branch_to_keep.pr_title
        },
        {
          :number       => pr_branch_to_change.pr_number,
          :html_url     => "https://example.com/#{repo.name}",
          :merge_target => pr_branch_to_change.merge_target,
          :pr_title     => "New Title"
        },
        {
          :number       => pr_number_to_create,
          :html_url     => "https://example.com/SomeOtherUser/some_other_repo",
          :merge_target => "master",
          :pr_title     => "New PR"
        }
      ])

      branches = repo.branches.order(:id)
      expect(branches.size).to eq(3)

      expect(results).to eq(
        :unchanged => [pr_branch_to_keep],
        :updated   => [pr_branch_to_change],
        :added     => [branches[2]],
        :deleted   => [pr_branch_to_delete]
      )

      expect(branches[0]).to eq(pr_branch_to_keep)
      expect(branches[0].attributes.except("last_changed_on")).to eq(pr_branch_to_keep.attributes.except("last_changed_on"))
      expect(branches[0].last_changed_on.to_i).to eq(pr_branch_to_keep.last_changed_on.to_i) # Ignore microsecond differences from the database

      expect(branches[1]).to eq(pr_branch_to_change)
      expect(branches[1].attributes.except("last_changed_on", "pr_title")).to eq(pr_branch_to_change.attributes.except("last_changed_on", "pr_title"))
      expect(branches[1].pr_title).to eq("New Title")

      expect(branches[2]).to have_attributes(
        :name         => "prs/#{pr_number_to_create}/head",
        :commits_list => [],
        :commit_uri   => "https://example.com/SomeOtherUser/some_other_repo/commit/$commit",
        :pull_request => true,
        :merge_target => "master",
        :pr_title     => "New PR",
        :last_commit  => "123abc",
      )

      expect { pr_branch_to_delete.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "handles pruning PR branches" do
      pr_branch = create(:pr_branch, :repo => repo)

      expect(repo).to receive(:git_fetch)

      repo.synchronize_pr_branches([])

      expect(repo.branches).to be_empty
    end

    it "handles when there are no PR branches" do
      repo.save!

      expect(repo).to receive(:git_fetch)

      expect { repo.synchronize_pr_branches([]) }.to_not raise_error
    end
  end

  describe "#enabled_for?" do
    subject(:repo) { build(:repo, :name => "foo/bar") }

    let(:settings) do
      { "checker_1" => { "enabled_repos" => { "foo/bar" => [{ "pattern" => "ansible_tower", "label" => "bug" }] }},
        "checker_2" => { "enabled_repos" => {} },
        "checker_3" => { "enabled_repos" => ["foo/bar"] },
        "checker_4" => { "enabled_repos" => ["not/theone"] },
        "checker_5" => { "enabled_repos" => "foo/bar" },
        "checker_6" => { "enabled_repos" => "not/theone" } }
    end

    before { stub_settings(settings) }

    it "handles hashes" do
      expect(repo.enabled_for?("checker_1")).to be_truthy
      expect(repo.enabled_for?("checker_2")).to be_falsey
    end

    it "handles arrays" do
      expect(repo.enabled_for?("checker_3")).to be_truthy
      expect(repo.enabled_for?("checker_4")).to be_falsey
    end

    it "handles strings" do
      expect(repo.enabled_for?("checker_5")).to be_truthy
      expect(repo.enabled_for?("checker_6")).to be_falsey
    end
  end
end
