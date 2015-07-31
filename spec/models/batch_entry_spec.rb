require 'spec_helper'

describe BatchEntry do
  describe "#succeeded?" do
    {
      nil         => false,
      "started"   => false,
      "failed"    => false,
      "succeeded" => true
    }.each do |state, expected|
      it "when #{state}" do
        entry = described_class.new(:state => state)
        expect(entry.succeeded?).to be expected
      end
    end
  end

  describe "#failed?" do
    {
      nil         => false,
      "started"   => false,
      "failed"    => true,
      "succeeded" => false
    }.each do |state, expected|
      it "when #{state}" do
        entry = described_class.new(:state => state)
        expect(entry.failed?).to be expected
      end
    end
  end

  describe "#complete?" do
    {
      nil         => false,
      "started"   => false,
      "failed"    => true,
      "succeeded" => true
    }.each do |state, expected|
      it "when #{state}" do
        entry = described_class.new(:state => state)
        expect(entry.complete?).to be expected
      end
    end
  end
end
