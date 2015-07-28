require "spec_helper"

RSpec.describe IssueManagerWorker do
  describe "#repo_names" do
    it "returns the list of repo names from the settings" do
      repo_name = "foo/bar"
      issue_manager = double("issue manager")
      allow(Settings).to receive_message_chain(:issue_manager, :repo_names).and_return([repo_name])
      allow(IssueManager).to receive(:new).with(repo_name).and_return(issue_manager)

      expect(described_class.new.repo_names).to eq([repo_name])
    end
  end

  describe ".new" do
    it "raises an error if the list of repo names is not provided" do
      allow(Settings).to receive_message_chain(:issue_manager, :repo_names).and_return(nil)

      expect { described_class.new }.to raise_error(/No repos defined/)
    end

    it "raises an error if the list of repo names is empty" do
      allow(Settings).to receive_message_chain(:issue_manager, :repo_names).and_return([])

      expect { described_class.new }.to raise_error(/No repos defined/)
    end
  end

  describe "#perform" do
    it "gets notifications from each issue manager" do
      repo_name = "foo/bar"
      issue_manager = double("issue manager")
      allow(Settings).to receive_message_chain(:issue_manager, :repo_names).and_return([repo_name])
      allow(IssueManager).to receive(:new).with(repo_name).and_return(issue_manager)

      expect(issue_manager).to receive(:get_notifications).once

      described_class.new.perform
    end

    it "recovers from errors raised by an issue manager" do
      repo_1 = "foo/bar"
      repo_2 = "baz/qux"
      issue_manager_1 = double("foo/bar")
      issue_manager_2 = double("baz/qux")
      allow(Settings).to receive_message_chain(:issue_manager, :repo_names).and_return([repo_1, repo_2])
      allow(IssueManager).to receive(:new).with(repo_1).and_return(issue_manager_1)
      allow(IssueManager).to receive(:new).with(repo_2).and_return(issue_manager_2)

      allow(issue_manager_1).to receive(:get_notifications).and_raise("boom")
      expect(issue_manager_2).to receive(:get_notifications)

      expect { described_class.new.perform }.not_to raise_error
    end
  end
end
