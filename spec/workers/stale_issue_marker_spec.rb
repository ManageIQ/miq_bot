require "spec_helper"

RSpec.describe StaleIssueMarker do
  let(:fq_repo_name) { "foo/bar" }

  let(:already_stale_issue) do
    double("already_stale_issue",
           :updated_at    => 8.months.ago,
           :fq_repo_name  => fq_repo_name,
           :number        => 3,
           :pull_request? => false,
           :labels        => %w(stale bug))
  end

  let(:stale_issue) do
    double("stale_issue",
           :updated_at    => 7.months.ago,
           :fq_repo_name  => fq_repo_name,
           :number        => 4,
           :pull_request? => false,
           :labels        => ["bug"])
  end

  let(:stale_pr) do
    double("stale_pr",
           :updated_at    => 7.months.ago,
           :fq_repo_name  => fq_repo_name,
           :number        => 2,
           :pull_request? => true,
           :labels        => [])
  end

  let(:fresh_issue) do
    double("fresh_issue",
           :updated_at    => 2.months.ago,
           :fq_repo_name  => fq_repo_name,
           :number        => 5,
           :pull_request? => false,
           :labels        => ["bug"])
  end

  let(:fresh_pr) do
    double("fresh_pr",
           :updated_at    => 2.months.ago,
           :fq_repo_name  => fq_repo_name,
           :number        => 6,
           :pull_request? => true,
           :labels        => ["bug"])
  end

  let(:stale_but_pinned_issue) do
    double("stale_but_pinned_issue",
           :updated_at    => 9.months.ago,
           :fq_repo_name  => fq_repo_name,
           :number        => 1,
           :pull_request? => true,
           :labels        => %w(bug pinned))
  end

  let(:issues) do
    [already_stale_issue,
     stale_issue,
     stale_pr,
     fresh_issue,
     fresh_pr,
     stale_but_pinned_issue]
  end

  before do
    allow(GithubService).to receive(:issues)
      .with(fq_repo_name, :state => :open, :sort => :updated, :direction => :asc)
      .and_return(issues)
    allow(GithubService).to receive(:valid_label?).with(fq_repo_name, "stale").and_return(true)
    allow(Sidekiq).to receive(:logger).and_return(double(:info => nil))
  end

  after do
    described_class.new.perform(fq_repo_name)
  end

  it "closes stale PRs and marks stale issues, respecting pins and commenting accordingly" do
    expect(stale_issue).to receive(:add_labels).with(["stale"])
    expect(stale_issue).to receive(:add_comment).with(/This issue.*marked as stale/)

    expect(GithubService).to receive(:close_pull_request).with(fq_repo_name, stale_pr.number)
    expect(stale_pr).to receive(:add_comment).with(/This pull request.*closed/)

    issues.each do |issue|
      unless issue == stale_issue
        expect(issue).to_not receive(:add_labels)
      end
    end

    issues.each do |issue|
      unless issue == stale_pr
        expect(GithubService).to_not receive(:close_pull_request).with(issue.number)
      end
    end

    issues.each do |issue|
      unless [stale_pr, stale_issue].include?(issue)
        expect(issue).to_not receive(:add_comment)
      end
    end
  end
end
