require 'spec_helper'

describe Branch do
  let(:last_commit) { "123abc" }
  let(:commit1)     { "234def" }
  let(:commit2)     { "345cde" }

  let(:repo) do
    Repo.create!(
      :upstream_user => "test-user",
      :name          => "test-repo",
      :path          => "/path/to/repo"
    )
  end

  let(:branch) do
    described_class.create!(
      :name        => "test-branch",
      :repo        => repo,
      :last_commit => last_commit,
      :commit_uri  => "https://uri.to/commit/$commit"
    )
  end

  context ".github_commit_uri" do
    it "(user, repo)" do
      actual = described_class.github_commit_uri("ManageIQ", "sandbox")
      expect(actual).to eq("https://github.com/ManageIQ/sandbox/commit/$commit")
    end

    it "(user, repo, sha)" do
      actual = described_class.github_commit_uri("ManageIQ", "sandbox", commit1)
      expect(actual).to eq("https://github.com/ManageIQ/sandbox/commit/#{commit1}")
    end
  end

  context ".github_compare_uri" do
    it "(user, repo)" do
      actual = described_class.github_compare_uri("ManageIQ", "sandbox")
      expect(actual).to eq("https://github.com/ManageIQ/sandbox/compare/$commit1...$commit2")
    end

    it "(user, repo, sha1, sha2)" do
      actual = described_class.github_compare_uri("ManageIQ", "sandbox", commit1, commit2)
      expect(actual).to eq("https://github.com/ManageIQ/sandbox/compare/#{commit1}...#{commit2}")
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
        branch.last_commit = commit1
        expect(branch.last_changed_on).to eq Time.now
      end
    end
  end

  it "#commit_uri_to" do
    expect(branch.commit_uri_to(commit1)).to eq "https://uri.to/commit/#{commit1}"
  end

  it "#last_commit_uri" do
    expect(branch.last_commit_uri).to eq "https://uri.to/commit/#{last_commit}"
  end

  it "#compare_uri_for" do
    expect(branch.compare_uri_for(commit1, commit2)).to eq "https://uri.to/compare/#{commit1}...#{commit2}"
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
