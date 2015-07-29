require "spec_helper"

RSpec.describe IssueManagerWorker do
  before  { stub_sidekiq_logger(described_class) }
  subject { described_class.new }

  def stub_issue_managers(*org_repo_pairs)
    allow(Settings).to receive_message_chain(:issue_manager, :repo_names).and_return(org_repo_pairs.collect(&:last))
    org_repo_pairs.collect.with_index do |(org_name, repo_name), i|
      CommitMonitorRepo.create!(
        :name          => repo_name,
        :upstream_user => org_name,
        :path          => Rails.root.join("repos/#{repo_name}")
      )

      double("issue manager #{i}").tap do |issue_manager|
        allow(IssueManager).to receive(:new).with(org_name, repo_name).and_return(issue_manager)
      end
    end
  end

  describe "#perform" do
    it "skips if the list of repo names is not provided" do
      allow(Settings).to receive_message_chain(:issue_manager, :repo_names).and_return(nil)

      expect(IssueManager).to_not receive(:new)
      subject.perform
    end

    it "skips if the list of repo names is empty" do
      allow(Settings).to receive_message_chain(:issue_manager, :repo_names).and_return([])

      expect(IssueManager).to_not receive(:new)
      subject.perform
    end

    it "gets notifications from an issue manager" do
      im = stub_issue_managers(["SomeOrg", "some_repo"]).first

      expect(im).to receive(:process_notifications).once
      subject.perform
    end

    it "gets notifications from multiple issue managers" do
      im1, im2 = stub_issue_managers(["SomeOrg", "some_repo1"], ["SomeOrg", "some_repo2"])

      expect(im1).to receive(:process_notifications).once
      expect(im2).to receive(:process_notifications).once
      subject.perform
    end

    it "recovers from errors raised by an issue manager" do
      im1, im2 = stub_issue_managers(["SomeOrg", "some_repo1"], ["SomeOrg", "some_repo2"])

      expect(im1).to receive(:process_notifications).once.and_raise("boom")
      expect(im2).to receive(:process_notifications).once

      expect { subject.perform }.not_to raise_error
    end
  end
end
