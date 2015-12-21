require "spec_helper"

RSpec.describe GithubNotificationMonitorWorker do
  before  { stub_sidekiq_logger(described_class) }
  subject { described_class.new }

  def stub_github_notification_monitors(*org_repo_pairs)
    repo_names = org_repo_pairs.collect { |pair| pair.join("/") }
    stub_settings(:github_notification_monitor, :repo_names, repo_names)

    org_repo_pairs.collect.with_index do |(org, repo), i|
      create(:repo, :name => "#{org}/#{repo}")

      double("github notification monitor #{i}").tap do |notification_monitor|
        allow(GithubNotificationMonitor).to receive(:build).with(org, repo).and_return(notification_monitor)
      end
    end
  end

  describe "#perform" do
    it "skips if the list of repo names is not provided" do
      stub_settings(:github_notification_monitor, :repo_names, nil)

      expect(GithubNotificationMonitor).to_not receive(:build)
      subject.perform
    end

    it "skips if the list of repo names is empty" do
      stub_settings(:github_notification_monitor, :repo_names, [])

      expect(GithubNotificationMonitor).to_not receive(:build)
      subject.perform
    end

    it "gets notifications from a notification monitor" do
      nm = stub_github_notification_monitors(["SomeOrg", "some_repo"]).first

      expect(nm).to receive(:process_notifications).once
      subject.perform
    end

    it "gets notifications from multiple notification monitors" do
      nm1, nm2 = stub_github_notification_monitors(["SomeOrg", "some_repo1"], ["SomeOrg", "some_repo2"])

      expect(nm1).to receive(:process_notifications).once
      expect(nm2).to receive(:process_notifications).once
      subject.perform
    end

    it "handles errors raised by a notification monitor" do
      nm1, nm2 = stub_github_notification_monitors(["SomeOrg", "some_repo1"], ["SomeOrg", "some_repo2"])

      expect(nm1).to receive(:process_notifications).once.and_raise("boom")
      expect(nm2).to receive(:process_notifications).once

      expect { subject.perform }.not_to raise_error
    end
  end
end
