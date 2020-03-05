require "spec_helper"

RSpec.describe StaleIssueMarker do
  def create_stub_issue(name, data)
    agent = GithubService.send(:service).agent
    GithubService::Issue.new(Sawyer::Resource.new(agent, {:name => name}.merge(data)))
  end

  def labels(label_names)
    label_names.map { |n| {:name => n} }
  end

  let(:subject)      { described_class.new }
  let(:stale_date)   { 6.months.ago }
  let(:repo_url)     { "https://api.github.com/repos/#{fq_repo_name}" }
  let(:fq_repo_name) { "foo/bar" }

  let(:already_stale_issue) do
    create_stub_issue("already_stale_issue",
                      :updated_at     => 3.months.ago, # last update is from the bot
                      :repository_url => repo_url,
                      :number         => 3,
                      :labels         => labels(%w[stale bug]))
  end

  let(:stale_issue) do
    create_stub_issue("stale_issue",
                      :updated_at     => 5.months.ago,
                      :repository_url => repo_url,
                      :number         => 4,
                      :labels         => labels(["bug"]))
  end

  let(:stale_pr) do
    create_stub_issue("stale_pr",
                      :updated_at     => 4.months.ago,
                      :repository_url => repo_url,
                      :number         => 2,
                      :pull_request   => true,
                      :labels         => [])
  end

  let(:stale_and_unmergable_pr) do
    create_stub_issue("stale_and_unmergable_pr",
                      :updated_at     => 4.months.ago,
                      :repository_url => repo_url,
                      :number         => 9001,
                      :pull_request   => true,
                      :labels         => labels(["stale", "unmergeable"]))
  end

  let(:issues) do
    [already_stale_issue,
     stale_issue,
     stale_pr]
  end

  let(:all_issues)        { issues + [stale_and_unmergable_pr] }
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
    all_issues.each do |issue|
      if [already_stale_issue, stale_and_unmergable_pr].include?(issue)
        expect(issue).to     receive(:add_comment).with(/This pull request.*closed/)
        expect(issue).to_not receive(:add_labels)
        expect(GithubService).to receive(:close_pull_request).with(fq_repo_name, issue.number)
      else
        expect(issue).to receive(:add_labels).with(["stale"])
        expect(issue).to receive(:add_comment).with(/This issue.*marked as stale/)
        expect(GithubService).to_not receive(:close_pull_request).with(issue.number)
      end
    end
  end
end
