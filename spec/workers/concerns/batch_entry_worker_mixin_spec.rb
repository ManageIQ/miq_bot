require 'spec_helper'

describe BatchEntryWorkerMixin do
  subject do
    Class.new do
      include BatchEntryWorkerMixin

      def logger
        @logger ||= RSpec::Mocks::Double.new("logger")
      end
    end.new
  end
  let(:entry) { BatchEntry.create! }

  describe "#find_batch_entry" do
    it "with an existing entry" do
      expect(subject.find_batch_entry(entry.id)).to be true
    end

    it "with a missing entry" do
      expect(subject.logger).to receive(:warn) do |message|
        expect(message).to match(/no longer exists/)
      end
      expect(subject.find_batch_entry(-1)).to be false
    end
  end

  it "#batch_job" do
    job = BatchJob.create!(:entries => [entry])
    subject.find_batch_entry(entry.id)

    expect(subject.batch_job).to eq(job)
  end

  describe "#complete_batch_entry" do
    before do
      subject.find_batch_entry(entry.id)
      expect(subject.batch_entry).to receive(:check_job_complete)
    end

    it "with no changes" do
      subject.complete_batch_entry

      expect(subject.batch_entry.state).to  eq("succeeded")
      expect(subject.batch_entry.result).to be_nil
    end

    it "with changes" do
      subject.complete_batch_entry(:result => "something")

      expect(subject.batch_entry.state).to  eq("succeeded")
      expect(subject.batch_entry.result).to eq("something")
    end

    it "with changes to " do
      subject.complete_batch_entry(:state => "failed", :result => "failure reason")

      expect(subject.batch_entry.state).to  eq("failed")
      expect(subject.batch_entry.result).to eq("failure reason")
    end
  end
end
