RSpec.describe GithubService::Commands::Assign do
  subject { described_class.new(issue) }
  let(:issue) { double(:fq_repo_name => "foo/bar") }
  let(:command_issuer) { "chessbyte" }

  before do
    allow(GithubService).to receive(:valid_assignee?).with("foo/bar", "gooduser") { true }
    allow(GithubService).to receive(:valid_assignee?).with("foo/bar", "baduser") { false }
  end

  after do
    subject.execute!(:issuer => command_issuer, :value => command_value)
  end

  context "with a valid user" do
    let(:command_value) { "gooduser" }

    it "assigns to that user" do
      expect(issue).to receive(:assign).with("gooduser")
    end
  end

  context "with an invalid user" do
    let(:command_value) { "baduser" }

    it "does not assign, reports failure" do
      expect(issue).not_to receive(:assign)
      expect(issue).to receive(:add_comment).with("@#{command_issuer} 'baduser' is an invalid assignee, ignoring...")
    end
  end
end
