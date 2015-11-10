require "rails_helper"

RSpec.describe IssueManagerWorker do
  before  { stub_sidekiq_logger(described_class) }
  subject { described_class.new }

  def stub_issue_managers(*org_repo_pairs)
    repo_names = org_repo_pairs.collect { |pair| pair.join("/") }
    stub_settings(:issue_manager, :repo_names, repo_names)

    org_repo_pairs.collect.with_index do |(org, repo), i|
      create(:repo, :name => "#{org}/#{repo}")

      double("issue manager #{i}").tap do |issue_manager|
        allow(IssueManager).to receive(:build).with(org, repo).and_return(issue_manager)
      end
    end
  end

  describe "#perform" do
    it "skips if the list of repo names is not provided" do
      stub_settings(:issue_manager, :repo_names, nil)

      expect(IssueManager).to_not receive(:build)
      subject.perform
    end

    it "skips if the list of repo names is empty" do
      stub_settings(:issue_manager, :repo_names, [])

      expect(IssueManager).to_not receive(:build)
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

    it "handles errors raised by an issue manager" do
      im1, im2 = stub_issue_managers(["SomeOrg", "some_repo1"], ["SomeOrg", "some_repo2"])

      expect(im1).to receive(:process_notifications).once.and_raise("boom")
      expect(im2).to receive(:process_notifications).once

      expect { subject.perform }.not_to raise_error
    end
  end
end
