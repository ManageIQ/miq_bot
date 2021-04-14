RSpec.describe Linter::Haml do
  subject        { described_class.new(double("branch")) }
  let(:stub_dir) { File.expand_path(File.join(*%w[.. .. .. vendor stubs]), __dir__) }

  describe "#linter_env" do
    it "is an empty hash" do
      expect(subject.send(:linter_env)).to eq({"RUBYOPT" => "-I #{stub_dir}"})
    end
  end
end
