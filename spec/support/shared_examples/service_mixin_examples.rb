shared_examples_for "ServiceMixin service" do
  context ".new" do
    it "is private" do
      expect { described_class.new }.to raise_error(NoMethodError)
    end
  end

  context ".call" do
    it "will synchronize multiple callers" do
      t = Thread.new do
        with_service do |service|
          Thread.current[:locked] = true
          sleep 0.01 until Thread.current[:release]
        end
      end
      t.abort_on_exception = true
      sleep 0.01 until t[:locked]

      expect(described_class.send(:mutex)).to be_locked

      t[:release] = true
      t.join
    end
  end
end
