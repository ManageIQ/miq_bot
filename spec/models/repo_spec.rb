require 'spec_helper'

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
      pr_branch_to_keep   = create(:pr_branch)
      pr_branch_to_delete = create(:pr_branch)
      pr_number_to_create = pr_branch_to_delete.pr_number + 1

      repo.update_attributes(:branches => [pr_branch_to_keep, pr_branch_to_delete])

      git_service = double("Git service", :merge_base => "123abc")
      expect(repo).to receive(:git_fetch)
      expect_any_instance_of(Branch).to receive(:git_service).and_return(git_service)

      repo.synchronize_pr_branches([
        {
          :number       => pr_branch_to_keep.pr_number,
          :html_url     => "https://example.com/SomeUser/some_repo",
          :merge_target => "master"
        },
        {
          :number       => pr_number_to_create,
          :html_url     => "https://example.com/SomeOtherUser/some_other_repo",
          :merge_target => "master"
        }
      ])

      branches = repo.branches.order(:id)
      expect(branches.size).to eq(2)
      expect(branches[0]).to eq(pr_branch_to_keep)
      expect(branches[0].attributes.except("last_changed_on")).to eq(pr_branch_to_keep.attributes.except("last_changed_on"))
      expect(branches[0].last_changed_on.to_i).to eq(pr_branch_to_keep.last_changed_on.to_i) # Ignore microsecond differences from the database

      expect(branches[1]).to have_attributes(
        :name         => "prs/#{pr_number_to_create}/head",
        :commits_list => [],
        :commit_uri   => "https://example.com/SomeOtherUser/some_other_repo/commit/$commit",
        :pull_request => true,
        :merge_target => "master",
        :last_commit  => "123abc",
      )

      expect { pr_branch_to_delete.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "handles pruning PR branches" do
      pr_branch = create(:pr_branch)
      repo.update_attributes(:branches => [pr_branch])

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
end
