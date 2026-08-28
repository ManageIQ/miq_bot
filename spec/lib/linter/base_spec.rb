RSpec.describe Linter::Base do
  subject { described_class.new(branch) }

  let(:branch) { double("branch", :logger => logger, :name => "pr/1", :repo => double(:name => "foo/bar")) }
  let(:logger) { double("logger", :debug => nil, :info => nil) }

  describe "#run" do
    context "when the only candidate file was deleted" do
      before do
        allow(subject).to receive(:files_to_lint).and_return(["deleted.haml"])
        allow(subject).to receive(:collected_config_files).and_return([".haml-lint.yml"])
        allow(subject).to receive(:collected_files_to_lint).and_return([])
      end

      it "does not run the linter" do
        expect(subject).not_to receive(:run_linter)

        expect(subject.run).to be_nil
      end
    end
  end

  describe "#linter_env" do
    it "is an empty hash" do
      expect(subject.send(:linter_env)).to eq({})
    end
  end
end
