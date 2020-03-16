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

  describe "clone synchronization callbacks" do
    before { stub_const("#{described_class}::BASE_PATH", Pathname.new(Dir.mktmpdir)) }
    after  { described_class::BASE_PATH.rmtree }

    def create_clone(repo)
      repo.path.mkpath
      FileUtils.touch(repo.path.join(".keep"))
      repo.save!
      [repo.path, repo.path.parent]
    end

    describe "after_update :move_git_clone" do
      it "when the org exists to the same org" do
        path_was, org_path_was = create_clone(repo)

        repo.update!(:name => "SomeUser/foo")

        expect(repo.path.exist?).to    be true
        expect(path_was.exist?).to     be false
        expect(org_path_was.exist?).to be true
      end

      it "when the org exists to a new org" do
        path_was, org_path_was = create_clone(repo)

        repo.update!(:name => "foo/bar")

        expect(repo.path.exist?).to    be true
        expect(path_was.exist?).to     be false
        expect(org_path_was.exist?).to be false
      end

      it "when the org is shared with another repo" do
        path_was, org_path_was = create_clone(repo)
        create_clone(build(:repo))

        repo.update!(:name => "foo/bar")

        expect(repo.path.exist?).to    be true
        expect(path_was.exist?).to     be false
        expect(org_path_was.exist?).to be true
      end

      it "when the org exists to a repo without an org" do
        path_was, org_path_was = create_clone(repo)

        repo.update!(:name => "foo")

        expect(repo.path.exist?).to    be true
        expect(path_was.exist?).to     be false
        expect(org_path_was.exist?).to be false
      end

      it "when the org does not exist to a repo with an org" do
        repo.name = "bar"
        path_was, org_path_was = create_clone(repo)

        repo.update!(:name => "foo/bar")

        expect(repo.path.exist?).to    be true
        expect(path_was.exist?).to     be false
        expect(org_path_was.exist?).to be true # because that would be the REPO_PATH
      end
    end

    describe "after_destroy :remove_git_clone" do
      it "when the repo has an org" do
        path_was, org_path_was = create_clone(repo)

        repo.destroy

        expect(path_was.exist?).to     be false
        expect(org_path_was.exist?).to be false
      end

      it "when the org is shared with another repo" do
        path_was, org_path_was = create_clone(repo)
        create_clone(build(:repo))

        repo.destroy

        expect(path_was.exist?).to     be false
        expect(org_path_was.exist?).to be true
      end

      it "when the repo does not have an org" do
        repo.name = "foo"
        path_was, org_path_was = create_clone(repo)

        repo.destroy

        expect(path_was.exist?).to     be false
        expect(org_path_was.exist?).to be true # because that would be the REPO_PATH
      end
    end
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

  it ".path" do
    expect(described_class.path("foo/bar")).to eq Rails.root.join("repos", "foo", "bar")
  end

  it "#path" do
    expect(repo.path).to eq Rails.root.join("repos", repo.name)
  end

  describe ".org_path" do
    it "when there is an org" do
      expect(described_class.org_path("foo/bar")).to eq Rails.root.join("repos", "foo")
    end

    it "when there is not an org" do
      expect(described_class.org_path("foo")).to be_nil
    end
  end

  describe "#org_path" do
    it "when there is an org" do
      expect(repo.org_path).to eq Rails.root.join("repos", repo.name_parts.first)
    end

    it "when there is not an org" do
      repo.name = "foo"
      expect(repo.org_path).to be_nil
    end
  end

  it "#branch_names" do
    repo.save!
    branch1 = create(:branch, :repo => repo, :pull_request => true)
    branch2 = create(:branch, :repo => repo, :pull_request => false)

    expect(repo.branch_names).to match_array([branch1.name, branch2.name])
  end

  it "#regular_branches" do
    repo.save!
    _pr_branch      = create(:branch, :repo => repo, :pull_request => true)
    regular_branch1 = create(:branch, :repo => repo, :pull_request => false)
    regular_branch2 = create(:branch, :repo => repo, :pull_request => false)

    expect(repo.regular_branches).to match_array([regular_branch1, regular_branch2])
  end

  it "#regular_branch_names" do
    repo.save!
    _pr_branch      = create(:branch, :repo => repo, :pull_request => true)
    regular_branch1 = create(:branch, :repo => repo, :pull_request => false)
    regular_branch2 = create(:branch, :repo => repo, :pull_request => false)

    expect(repo.regular_branch_names).to match_array([regular_branch1.name, regular_branch2.name])
  end

  it "#pr_branches" do
    repo.save!
    pr_branch1      = create(:branch, :repo => repo, :pull_request => true)
    pr_branch2      = create(:branch, :repo => repo, :pull_request => true)
    _regular_branch = create(:branch, :repo => repo, :pull_request => false)

    expect(repo.pr_branches).to match_array([pr_branch1, pr_branch2])
  end

  it "#pr_branch_names" do
    repo.save!
    pr_branch1      = create(:branch, :repo => repo, :pull_request => true)
    pr_branch2      = create(:branch, :repo => repo, :pull_request => true)
    _regular_branch = create(:branch, :repo => repo, :pull_request => false)

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
end
