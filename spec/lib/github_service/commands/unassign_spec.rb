require 'spec_helper'

RSpec.describe GithubService::Commands::Unassign do
  subject { described_class.new(issue) }
  let(:issue) { double("Issue", :fq_repo_name => "org/repo") }
  let(:command_issuer) { "nickname" }
  let(:assigned_users) { ["listed_user"] }

  before do
    allow(subject).to receive(:list_assigned_users).and_return(assigned_users)
  end

  after do
    subject.execute!(:issuer => command_issuer, :value => command_value)
  end

  context "with a user who is in the list of assignees" do
    let(:command_value) { "listed_user" }

    it "unassigns pull request or issue from that user" do
      allow(issue).to receive(:number).and_return(42)
      expect(subject).to receive(:octokit_remove_assignees).with("org/repo", 42, %w(listed_user)).once
    end
  end

  context "with a user who is not in the list of assignees" do
    let(:command_value) { "non_listed_user" }

    it "do not unassign pull request or issue from that user" do
      expect(issue).not_to receive(:octokit_remove_assignees)
      expect(issue).to receive(:add_comment).with("@#{command_issuer} User 'non_listed_user' is not in the list of assignees, ignoring...")
    end
  end

  context "with users who are in the list of assignees" do
    let(:assigned_users) { %w(listed_user1 listed_user2) }
    let(:command_value) { "listed_user1, listed_user2" }

    it "unassigns pull request or issue from these users" do
      allow(issue).to receive(:number).and_return(42)
      expect(subject).to receive(:octokit_remove_assignees).with("org/repo", 42, %w(listed_user1 listed_user2)).once
    end
  end

  context "with users who are not in the list of assignees" do
    let(:assigned_users) { %w(listed_user1 listed_user2) }
    let(:command_value) { "non_listed_user1, non_listed_user2" }

    it "do not unassign pull request or issue from these users" do
      expect(issue).not_to receive(:octokit_remove_assignees)
      expect(issue).to receive(:add_comment).with("@#{command_issuer} Users 'non_listed_user1, non_listed_user2' are not in the list of assignees, ignoring...")
    end
  end
end
