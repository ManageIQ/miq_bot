require 'spec_helper'

describe Branch do
  let(:last_commit)  { "123abc" }
  let(:other_commit) { "234def" }

  let(:repo) do
    Repo.create!(
      :upstream_user => "test-user",
      :name          => "test-repo",
      :path          => "/path/to/repo"
    )
  end

  let(:branch) do
    Branch.create!(
      :name        => "test-branch",
      :repo        => repo,
      :last_commit => last_commit,
      :commit_uri  => "https://uri.to/commit/$commit"
    )
  end

  context ".github_commit_uri" do
    it "(user, repo)" do
      actual = Branch.github_commit_uri("ManageIQ", "sandbox")
      expect(actual).to eq("https://github.com/ManageIQ/sandbox/commit/$commit")
    end

    it "(user, repo, sha)" do
      actual = Branch.github_commit_uri("ManageIQ", "sandbox", "3616fc8ea9cfbcc2a7f70b8870f4a736ce6c91d5")
      expect(actual).to eq("https://github.com/ManageIQ/sandbox/commit/3616fc8ea9cfbcc2a7f70b8870f4a736ce6c91d5")
    end
  end

  context "#last_commit=" do
    it "will not modify last_changed_on if commit does not change" do
      branch # Create the branch before time freezing
      Timecop.freeze(10.minutes.from_now) do
        branch.last_commit = last_commit
        expect(branch.last_changed_on).to_not eq Time.now
      end
    end

    it "will modify last_changed_on if commit changes" do
      branch # Create the branch before time freezing
      Timecop.freeze(10.minutes.from_now) do
        branch.last_commit = other_commit
        expect(branch.last_changed_on).to eq Time.now
      end
    end
  end

  it "#commit_uri_to" do
    expect(branch.commit_uri_to(other_commit)).to eq "https://uri.to/commit/#{other_commit}"
  end

  it "#last_commit_uri" do
    expect(branch.last_commit_uri).to eq "https://uri.to/commit/#{last_commit}"
  end

  context "#mode" do
    it "on pr branch" do
      branch.name = "pr/133"
      branch.pull_request = true

      expect(branch.mode).to eq :pr
    end

    it "on regular branch" do
      expect(branch.mode).to eq :regular
    end
  end

  context "#pr_number" do
    it "on pr branch" do
      branch.name = "pr/133"
      branch.pull_request = true

      expect(branch.pr_number).to eq 133
    end

    it "on regular branch" do
      expect(branch.pr_number).to be_nil
    end
  end

  describe "#github_pr_uri" do
    it "creates correct pr uri" do
      branch.name = "pr/123"
      branch.pull_request = true
      actual = branch.github_pr_uri
      expect(actual).to eq("https://github.com/test-user/test-repo/pull/123")
    end

    it "returns nil on non-pr branches" do
      branch.pull_request = false
      expect(branch.github_pr_uri).to be_nil
    end
  end

  it "#write_github_comment raises on non-pr branches" do
    branch.pull_request = false
    expect { branch.write_github_comment("<test /> blah") }.to raise_error(ArgumentError)
  end
end
