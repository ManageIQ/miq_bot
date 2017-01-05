require 'spec_helper'

RSpec.describe GithubNotificationMonitor do
  describe "#process_notifications" do
    before do
      allow(File).to receive(:write).with(described_class::GITHUB_NOTIFICATION_MONITOR_YAML_FILE, anything)
    end

    let(:username) { "miq-bot" }

    it "assigns to a user" do
      assignee = "gooduser"
      issue_number = 1
      body = "@miq-bot assign #{assignee}"
      issue = instance_spy(
        "GithubApi::Issue",
        :body       => body,
        :number     => issue_number,
        :created_at => 5.minutes.ago
      )
      repo = instance_spy(
        "GithubApi::Repo",
        :notifications => [
          instance_spy(
            "GithubApi::Notification",
            :issue => issue
          )
        ]
      )
      allow(repo).to receive(:valid_assignee?).with(assignee).and_return(true)
      fq_repo_name = "bar/baz"
      stub_timestamps_for_repo_with_issue_number(fq_repo_name, issue_number, 10.minutes.ago)

      expect(issue).to receive(:assign).with(assignee)

      described_class.new(repo, username, fq_repo_name).process_notifications
    end

    it "does not assign to an invalid user" do
      assignee = "baduser"
      issue_number = 1
      body = "@miq-bot assign #{assignee}"
      issue = instance_spy(
        "GithubApi::Issue",
        :body       => body,
        :number     => issue_number,
        :created_at => 5.minutes.ago
      )
      repo = instance_spy(
        "GithubApi::Repo",
        :notifications => [
          instance_spy(
            "GithubApi::Notification",
            :issue => issue
          )
        ]
      )
      allow(repo).to receive(:valid_assignee?).with(assignee).and_return(false)
      fq_repo_name = "bar/baz"
      stub_timestamps_for_repo_with_issue_number(fq_repo_name, issue_number, 10.minutes.ago)

      expect(issue).not_to receive(:assign)

      described_class.new(repo, username, fq_repo_name).process_notifications
    end

    it "adds valid labels" do
      issue_number = 1
      body = "@miq-bot add-label question, wontfix"
      issue = instance_spy(
        "GithubApi::Issue",
        :body           => body,
        :number         => issue_number,
        :created_at     => 5.minutes.ago,
        :applied_label? => false
      )
      repo = instance_spy(
        "GithubApi::Repo",
        :notifications => [
          instance_spy(
            "GithubApi::Notification",
            :issue => issue
          )
        ]
      )
      allow(repo).to receive(:valid_label?) { |arg| %(question wontfix).include?(arg) }
      fq_repo_name = "bar/baz"
      stub_timestamps_for_repo_with_issue_number(fq_repo_name, issue_number, 10.minutes.ago)

      expect(issue).to receive(:add_labels) do |labels|
        expect(labels.map(&:text)).to contain_exactly("question", "wontfix")
      end

      described_class.new(repo, username, fq_repo_name).process_notifications
    end

    it "does not add invalid labels" do
      issue_number = 1
      body = "@miq-bot add-label invalidlabel"
      issue = instance_spy(
        "GithubApi::Issue",
        :body           => body,
        :number         => issue_number,
        :created_at     => 5.minutes.ago,
        :applied_label? => false
      )
      repo = instance_spy(
        "GithubApi::Repo",
        :notifications => [
          instance_spy(
            "GithubApi::Notification",
            :issue => issue
          )
        ]
      )
      allow(repo).to receive(:valid_label?).with("invalidlabel").and_return(false)
      fq_repo_name = "bar/baz"
      stub_timestamps_for_repo_with_issue_number(fq_repo_name, issue_number, 10.minutes.ago)

      expect(issue).not_to receive(:add_labels)

      described_class.new(repo, username, fq_repo_name).process_notifications
    end

    it "remove applied label" do
      issue_number = 1
      body = "@miq-bot remove-label question"
      issue = instance_spy(
        "GithubApi::Issue",
        :body       => body,
        :number     => issue_number,
        :created_at => 5.minutes.ago
      )
      allow(issue).to receive(:applied_label).with("question").and_return(true)
      repo = instance_spy(
        "GithubApi::Repo",
        :notifications => [
          instance_spy(
            "GithubApi::Notification",
            :issue => issue
          )
        ]
      )
      allow(repo).to receive(:valid_label?) { |arg| %(question wontfix).include?(arg) }
      fq_repo_name = "bar/baz"
      stub_timestamps_for_repo_with_issue_number(fq_repo_name, issue_number, 10.minutes.ago)

      expect(issue).to receive(:remove_label).with("question")

      described_class.new(repo, username, fq_repo_name).process_notifications
    end

    it "remove unapplied label" do
      issue_number = 1
      body = "@miq-bot remove-label invalidlabel"
      issue = instance_spy(
        "GithubApi::Issue",
        :body       => body,
        :number     => issue_number,
        :created_at => 5.minutes.ago
      )
      allow(issue).to receive(:applied_label).with("invalidlabel").and_return(false)
      repo = instance_spy(
        "GithubApi::Repo",
        :notifications => [
          instance_spy(
            "GithubApi::Notification",
            :issue => issue
          )
        ]
      )
      allow(repo).to receive(:valid_label?) { |arg| %(question wontfix).include?(arg) }
      fq_repo_name = "bar/baz"
      stub_timestamps_for_repo_with_issue_number(fq_repo_name, issue_number, 10.minutes.ago)

      expect(issue).not_to receive(:remove_label)

      described_class.new(repo, username, fq_repo_name).process_notifications
    end

    it "extra space in command" do
      issue_number = 1
      body = "@miq-bot add label question, wontfix"
      issue = instance_spy(
        "GithubApi::Issue",
        :body           => body,
        :number         => issue_number,
        :created_at     => 5.minutes.ago,
        :applied_label? => false
      )
      repo = instance_spy(
        "GithubApi::Repo",
        :notifications => [
          instance_spy(
            "GithubApi::Notification",
            :issue => issue
          )
        ]
      )
      allow(repo).to receive(:valid_label?) { |arg| %(question wontfix).include?(arg) }
      fq_repo_name = "bar/baz"
      stub_timestamps_for_repo_with_issue_number(fq_repo_name, issue_number, 10.minutes.ago)

      expect(issue).not_to receive(:add_labels)

      described_class.new(repo, username, fq_repo_name).process_notifications
    end

    it "extra comma in command values" do
      issue_number = 1
      body = "@miq-bot add-label question, wontfix,"
      issue = instance_spy(
        "GithubApi::Issue",
        :body           => body,
        :number         => issue_number,
        :created_at     => 5.minutes.ago,
        :applied_label? => false
      )
      repo = instance_spy(
        "GithubApi::Repo",
        :notifications => [
          instance_spy(
            "GithubApi::Notification",
            :issue => issue
          )
        ]
      )
      allow(repo).to receive(:valid_label?) { |arg| %(question wontfix).include?(arg) }
      fq_repo_name = "bar/baz"
      stub_timestamps_for_repo_with_issue_number(fq_repo_name, issue_number, 10.minutes.ago)

      expect(issue).to receive(:add_labels) do |labels|
        expect(labels.map(&:text)).to contain_exactly("question", "wontfix")
      end

      described_class.new(repo, username, fq_repo_name).process_notifications
    end
  end

  def stub_timestamps_for_repo_with_issue_number(repo, issue_number, timestamp)
    allow(YAML).to receive(:load_file).with(described_class::GITHUB_NOTIFICATION_MONITOR_YAML_FILE) do
      {"timestamps" => {repo => {issue_number => timestamp}}}
    end
  end
end
