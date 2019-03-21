require 'rails_helper'

RSpec.describe GithubNotificationMonitor do
  subject(:notification_monitor) { described_class.new(fq_repo_name) }

  let(:notification) { double('notification', :issue_number => issue.number) }
  let(:issue) do
    double('issue',
           :author         => "notchrisarcand",
           :body           => "Opened this issue",
           :number         => 1,
           :created_at     => 15.minutes.ago,
           :labels         => [],
           :repository_url => "https://api.fakegithub.com/repos/#{fq_repo_name}")
  end
  let(:comments) do
    [
      double('comment',
             :author     => "Commenter One",
             :updated_at => 14.minutes.ago,
             :body       => "This is an old comment."),
      double('comment',
             :author     => "Commenter Two",
             :updated_at => 8.minutes.ago,
             :body       => "This is a new comment."),
      double('comment',
             :author     => "Commenter Three",
             :updated_at => 3.minutes.ago,
             :body       => "This is also a new comment.")
    ]
  end
  let(:username)     { "miq-bot" }
  let(:fq_repo_name) { "foo/bar" }
  let(:command_dispatcher) { double }

  describe "#process_notifications" do
    before do
      allow(Settings).to receive(:github_credentials).and_return(double(:username => username))
      allow(File).to receive(:write)
        .with(described_class::GITHUB_NOTIFICATION_MONITOR_YAML_FILE, anything)
      allow(YAML).to receive(:load_file)
        .with(described_class::GITHUB_NOTIFICATION_MONITOR_YAML_FILE) do
        { "timestamps" => { fq_repo_name => { issue.number => 10.minutes.ago } } }
      end
      allow(GithubService).to receive(:repository_notifications)
        .with(fq_repo_name, a_hash_including("all" => false)).and_return([notification])
      allow(GithubService).to receive(:issue)
        .with(fq_repo_name, notification.issue_number).and_return(issue)
      allow(GithubService).to receive(:issue_comments)
        .with(fq_repo_name, issue.number).and_return(comments)
    end

    after do
      notification_monitor.process_notifications
    end

    it "calls the command dispatcher for new comments and marks notification as read" do
      expect(GithubService::CommandDispatcher).to receive(:new).with(issue).and_return(command_dispatcher)
      expect(command_dispatcher).not_to receive(:dispatch!)
        .with(:issuer => "notchrisarcand", :text => issue.body)
      expect(command_dispatcher).not_to receive(:dispatch!)
        .with(:issuer => "Commenter One", :text => "This is an old comment.")
      expect(command_dispatcher).to receive(:dispatch!)
        .with(:issuer => "Commenter Two", :text => "This is a new comment.")
      expect(command_dispatcher).to receive(:dispatch!)
        .with(:issuer => "Commenter Three", :text => "This is also a new comment.")
      expect(notification).to receive(:mark_thread_as_read)
    end
  end
end
