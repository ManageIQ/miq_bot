RSpec.describe GithubService::Commands::AddLabel do
  subject { described_class.new(issue) }
  let(:issue) { double(:fq_repo_name => "foo/bar") }
  let(:command_issuer) { "chessbyte" }
  let(:command_value) { "question, wontfix" }

  before do
    allow(issue).to receive(:applied_label?).with("question").and_return(true)
    allow(issue).to receive(:applied_label?).with("wontfix").and_return(false)
    %w(question wontfix).each do |label|
      allow(GithubService).to receive(:valid_label?).with("foo/bar", label).and_return(true)
    end
  end

  after do
    subject.execute!(:issuer => command_issuer, :value => command_value)
  end

  context "with valid labels" do
    it "adds the unapplied labels" do
      expect(issue).to receive(:add_labels).with(["wontfix"])
    end
  end

  context "with invalid labels" do
    let(:command_value) { "invalidlabel" }

    before do
      allow(GithubService).to receive(:valid_label?).with("foo/bar", command_value).and_return(false)
    end

    it "does not add invalid labels and comments on error" do
      expect(issue).not_to receive(:add_labels)
      expect(issue).to receive(:add_comment).with(/Cannot apply the following label.*not recognized/)
    end
  end
end
