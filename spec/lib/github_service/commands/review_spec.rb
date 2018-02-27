require 'spec_helper'

RSpec.describe GithubService::Commands::AddReviewer do
  subject { described_class.new(issue) }
  let(:issue) { double(:fq_repo_name => "org/repo") }
  let(:command_issuer) { "nickname" }

  before do
    allow(GithubService).to receive(:valid_assignee?).with("org/repo", "good_user") { true }
    allow(GithubService).to receive(:valid_assignee?).with("org/repo", "bad_user") { false }
  end

  after do
    subject.execute!(:issuer => command_issuer, :value => command_value)
  end

  context "with a valid user" do
    let(:command_value) { "good_user" }

    it "review request that user" do
      expect(issue).to receive(:review).with("good_user")
    end
  end

  context "with an invalid user" do
    let(:command_value) { "bad_user" }

    it "does not review request, reports failure" do
      expect(issue).not_to receive(:assign)
      expect(issue).to receive(:add_comment).with("@#{command_issuer} 'bad_user' is an invalid reviewer, ignoring...")
    end
  end
end
