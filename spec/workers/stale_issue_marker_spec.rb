require "spec_helper"

RSpec.describe StaleIssueMarker do
  let(:subject)      { described_class.new }
  let(:stale_date)   { 6.months.ago }
  let(:fq_repo_name) { "foo/bar" }

  let(:already_stale_issue) do
    double("already_stale_issue",
           :updated_at    => 6.months.ago,
           :fq_repo_name  => fq_repo_name,
           :number        => 3,
           :pull_request? => false,
           :labels        => %w(stale bug))
  end

  let(:stale_issue) do
    double("stale_issue",
           :updated_at    => 5.months.ago,
           :fq_repo_name  => fq_repo_name,
           :number        => 4,
           :pull_request? => false,
           :labels        => ["bug"])
  end

  let(:stale_pr) do
    double("stale_pr",
           :updated_at    => 4.months.ago,
           :fq_repo_name  => fq_repo_name,
           :number        => 2,
           :pull_request? => true,
           :labels        => [])
  end

  let(:stale_and_unmergable_pr) do
    double("stale_and_unmergable_pr",
           :updated_at    => 4.months.ago,
           :fq_repo_name  => fq_repo_name,
           :number        => 9001,
           :pull_request? => true,
           :labels        => ["stale", "unmergeable"])
  end

  let(:issues) do
    [already_stale_issue,
     stale_issue,
     stale_pr]
  end

  let(:search_query)      { "#{issue_filter} #{update_filter} #{repo_filter} #{pinned_filter}" }
  let(:unmergeable_query) { "#{issue_filter} is:pr #{labels_filter} #{repo_filter} #{pinned_filter}" }
  let(:issue_filter)      { "is:open archived:false" }
  let(:update_filter)     { "update:<#{stale_date.strftime('%Y-%m-%d')}" }
  let(:repo_filter)       { %(repo:"#{fq_repo_name}") }
  let(:pinned_filter)     { %(-label:"pinned") }
  let(:labels_filter)     { %(label:"stale" label:"unmergeable") }

  before do
    allow(described_class).to receive(:enabled_repo_names).and_return([fq_repo_name])
    allow(subject).to receive(:stale_date).and_return(stale_date)
    allow(GithubService).to receive(:search_issues)
      .with(search_query, :sort => :updated, :direction => :asc)
      .and_return(issues)
    allow(GithubService).to receive(:search_issues)
      .with(unmergeable_query, :sort => :updated, :direction => :asc)
      .and_return([stale_and_unmergable_pr])
    allow(GithubService).to receive(:valid_label?).with(fq_repo_name, "stale").and_return(true)
    allow(Sidekiq).to receive(:logger).and_return(double(:info => nil))
  end

  after do
    subject.perform
  end

  it "closes stale PRs and marks stale issues, respecting pins and commenting accordingly" do
    expect(stale_issue).to receive(:add_labels).with(["stale"])
    expect(stale_issue).to receive(:add_comment).with(/This issue.*marked as stale/)

    expect(GithubService).to receive(:close_pull_request).with(fq_repo_name, stale_pr.number)
    expect(GithubService).to receive(:close_pull_request).with(fq_repo_name, stale_and_unmergable_pr.number)
    expect(stale_pr).to receive(:add_comment).with(/This pull request.*closed/)
    expect(stale_and_unmergable_pr).to receive(:add_comment).with(/This pull request.*closed/)

    issues.each do |issue|
      unless issue == stale_issue
        expect(issue).to_not receive(:add_labels)
      end
    end

    issues.each do |issue|
      unless [stale_pr, stale_and_unmergable_pr].include?(issue)
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
