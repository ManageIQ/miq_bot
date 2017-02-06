require "spec_helper"

RSpec.describe GitHubApi::Issue do
  describe "#add_labels" do
    it "updates the title with [WIP] when adding wip label" do
      octokit_issue = spy("Octokit::Issue", :title => "War and Peace")
      repo = spy("GitHubApi::Repo")
      label = instance_double("GitHubApi::Label", :text => "wip")
      issue = described_class.new(octokit_issue, repo)
      issue.instance_variable_set(:@applied_labels, "wip" => label)

      expect(GitHubApi)
        .to receive(:execute)
        .with(anything, :add_labels_to_an_issue, anything, anything, ["wip"])
        .once

      expect(GitHubApi)
        .to receive(:execute)
        .with(anything, :update_issue, anything, anything, :title => "[WIP] War and Peace")
        .once

      issue.add_labels([label])
    end
  end

  describe "#remove_label" do
    it "updates the title without [WIP] when removing wip label" do
      octokit_issue = spy("Octokit::Issue", :title => "[WIP] War and Peace")
      repo = spy("GitHubApi::Repo")
      issue = described_class.new(octokit_issue, repo)
      issue.instance_variable_set(:@applied_labels, {})

      expect(GitHubApi)
        .to receive(:execute)
        .with(anything, :remove_label, anything, anything, "wip")
        .once

      expect(GitHubApi)
        .to receive(:execute)
        .with(anything, :update_issue, anything, anything, :title => "War and Peace")
        .once

      issue.remove_label("wip")
    end
  end
end
