require 'spec_helper'

describe BatchJob do
  describe "#expired?" do
    it "without an expiration" do
      job = described_class.new
      expect(job).to_not be_expired
    end

    it "with an expiration, but not yet expired" do
      job = described_class.new(:expires_at => 10.minutes.from_now)
      expect(job).to_not be_expired
    end

    it "with an expiration, and expired" do
      job = described_class.new(:expires_at => 10.minutes.ago)
      expect(job).to be_expired
    end
  end

  describe "#complete?" do
    it "when expired" do
      job = described_class.new(:expires_at => 10.minutes.ago)
      expect(job).to be_complete
    end

    it "without entries" do
      job = described_class.new
      expect(job).to be_complete
    end

    it "with entries that are not complete" do
      job = described_class.new(:entries => [
        BatchEntry.new,
        BatchEntry.new(:state => "succeeded")
      ])
      expect(job).to_not be_complete
    end

    it "with entries that are complete" do
      job = described_class.new(:entries => [
        BatchEntry.new(:state => "failed"),
        BatchEntry.new(:state => "succeeded")
      ])
      expect(job).to be_complete
    end
  end
end
