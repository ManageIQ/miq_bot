RSpec.describe Linter::Base do
  subject { described_class.new(double("branch")) }

  describe "#linter_env" do
    it "is an empty hash" do
      expect(subject.send(:linter_env)).to eq({})
    end
  end
end
