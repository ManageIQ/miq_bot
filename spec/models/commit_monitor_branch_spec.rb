require 'spec_helper'

describe CommitMonitorBranch do
  let(:branch) { CommitMonitorBranch.new(:last_commit => "123abc", :commit_uri => "https://uri.to/commit/$commit") }

  context ".github_commit_uri" do
    it "(user, repo)" do
      actual = CommitMonitorBranch.github_commit_uri("ManageIQ", "sandbox")
      expect(actual).to eq("https://github.com/ManageIQ/sandbox/commit/$commit")
    end

    it "(user, repo, sha)" do
      actual = CommitMonitorBranch.github_commit_uri("ManageIQ", "sandbox", "3616fc8ea9cfbcc2a7f70b8870f4a736ce6c91d5")
      expect(actual).to eq("https://github.com/ManageIQ/sandbox/commit/3616fc8ea9cfbcc2a7f70b8870f4a736ce6c91d5")
    end
  end

  it "#commit_uri_to" do
    expect(branch.commit_uri_to("234def")).to eq "https://uri.to/commit/234def"
  end

  it "#last_commit_uri" do
    expect(branch.last_commit_uri).to eq "https://uri.to/commit/123abc"
  end
end
