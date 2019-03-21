require 'rails_helper'

RSpec.describe GithubService::Commands::RemoveReviewer do
  subject { described_class.new(issue) }
  let(:issue) { double(:fq_repo_name => "org/repo") }
  let(:command_issuer) { "nickname" }

  before do
    allow(GithubService).to receive(:valid_assignee?).with("org/repo", "listed_user").and_return(true)
    allow(GithubService).to receive(:valid_assignee?).with("org/repo", "good_user").and_return(true)
    allow(GithubService).to receive(:valid_assignee?).with("org/repo", "bad_user").and_return(false)

    allow(subject).to receive(:requested_reviewers).and_return(["listed_user"])
  end

  after do
    subject.execute!(:issuer => command_issuer, :value => command_value)
  end

  context "with a valid user who is actually requested for a review" do
    let(:command_value) { "listed_user" }

    it "remove review request from that user" do
      expect(issue).to receive(:remove_reviewer).with("listed_user")
    end
  end

  context "with a valid user who is not actually requested for a review" do
    let(:command_value) { "good_user" }

    it "does not remove review request who is not actually requested" do
      expect(issue).not_to receive(:remove_reviewer)
      expect(issue).to receive(:add_comment).with("@#{command_issuer} 'good_user' is not in the list of requested reviewers, ignoring...")
    end
  end

  context "with an invalid user" do
    let(:command_value) { "bad_user" }

    it "does not remove review request, reports failure" do
      expect(issue).not_to receive(:remove_reviewer)
      expect(issue).to receive(:add_comment).with("@#{command_issuer} 'bad_user' is an invalid reviewer, ignoring...")
    end
  end
end
