shared_examples "state predicates" do |method, matrix|
  describe "##{method}" do
    matrix.each do |state, expected|
      it "when #{state}" do
        record = described_class.new(:state => state)
        expect(record.public_send(method)).to be expected
      end
    end
  end
end
