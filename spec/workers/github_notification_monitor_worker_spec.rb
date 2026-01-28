RSpec.describe GithubNotificationMonitorWorker do
  before  { stub_sidekiq_logger(described_class) }
  subject { described_class.new }

  def stub_github_notification_monitors(repo_names)
    stub_settings(:github_notification_monitor => {:repo_names => repo_names})

    notifications = []

    monitors = Array(repo_names).map do |repo_name|
      create(:repo, :name => repo_name)

      notification = double("notification for #{repo_name}", :repository => double("repo", :full_name => repo_name))
      notifications << notification

      double("github notification monitor for #{repo_name}").tap do |notification_monitor|
        expect(GithubNotificationMonitor).to receive(:new).with(repo_name, [notification]).and_return(notification_monitor)
      end
    end

    expect(GithubService).to receive(:notifications).with("all" => false).and_return(notifications)

    monitors
  end

  describe "#perform" do
    it "skips if the list of repo names is not provided" do
      stub_github_notification_monitors(nil)

      expect(GithubNotificationMonitor).to_not receive(:new)
      subject.perform
    end

    it "skips if the list of repo names is empty" do
      stub_github_notification_monitors([])

      expect(GithubNotificationMonitor).to_not receive(:new)
      subject.perform
    end

    it "gets notifications from a notification monitor" do
      nm = stub_github_notification_monitors(["SomeOrg/some_repo"]).first

      expect(nm).to receive(:process_notifications).once
      subject.perform
    end

    it "gets notifications from multiple notification monitors" do
      nm1, nm2 = stub_github_notification_monitors(["SomeOrg/some_repo1", "SomeOrg/some_repo2"])

      expect(nm1).to receive(:process_notifications).once
      expect(nm2).to receive(:process_notifications).once
      subject.perform
    end

    it "handles errors raised by a notification monitor" do
      nm1, nm2 = stub_github_notification_monitors(["SomeOrg/some_repo1", "SomeOrg/some_repo2"])

      expect(nm1).to receive(:process_notifications).once.and_raise("boom")
      expect(nm2).to receive(:process_notifications).once

      expect { subject.perform }.not_to raise_error
    end
  end
end
