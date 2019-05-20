RSpec.describe GithubService::Commands::RemoveLabel do
  subject { described_class.new(issue) }
  let(:issue) { double(:fq_repo_name => "foo/bar") }
  let(:command_issuer) { "chessbyte" }
  let(:command_value) { "question, wontfix" }

  after do
    subject.execute!(:issuer => command_issuer, :value => command_value)
  end

  context "with valid labels" do
    before do
      %w(question wontfix).each do |label|
        allow(GithubService).to receive(:valid_label?).with("foo/bar", label).and_return(true)
      end
    end

    context "when the labels are applied" do
      before do
        %w(question wontfix).each do |label|
          expect(issue).to receive(:applied_label?)
            .with(label).and_return(true)
        end
      end

      it "removes the labels" do
        %w(question wontfix).each do |label|
          expect(issue).to receive(:remove_label).with(label)
        end
      end
    end

    context "with some unapplied labels" do
      before do
        expect(issue).to receive(:applied_label?).with("question").and_return(true)
        expect(issue).to receive(:applied_label?).with("wontfix").and_return(false)
      end

      it "only removes the applied label" do
        expect(issue).to receive(:remove_label).with("question")
        expect(issue).not_to receive(:remove_label).with("wontfix")
      end
    end
  end
end
